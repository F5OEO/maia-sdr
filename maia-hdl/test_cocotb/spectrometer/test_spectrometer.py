#
# Copyright (C) 2026 Daniel Estevez <daniel@destevez.net>
#
# This file is part of maia-sdr
#
# SPDX-License-Identifier: MIT
#

# Spectrometer-level regression/integration test.
#
# No testbench previously existed for Spectrometer as a whole (only its
# submodules, e.g. Recorder16IQ and DmaBRAMWrite, were tested in
# isolation). This test deliberately does not aim for bit-exact FFT
# matching (that would require re-implementing the fixed-point FFT
# core's windowing/truncation as an oracle). Instead it checks
# structural properties using a constant (DC) input, which concentrates
# (nearly) all of the window-shaped spectrum at a single bin.
#
# Rather than hand-deriving which address that bin lands at after the
# bit-reversal + fftshift remap every channel in this design applies
# (spectrum_integrator.py's write_counter_shift/read_counter_shift, and
# Spectrometer's own iq_write_addr) -- which turned out, empirically,
# easy to get wrong by reasoning about it in the abstract -- this test
# finds the peak address empirically (scan every address, take the
# max) and checks it is dominant and, for the magnitude/I-Q channels
# (which share the exact same remap), that both channels agree on
# *which* address it's at. That cross-channel agreement is the
# actually load-bearing property (same tap point, same remap, so a
# wiring mistake in either would make them disagree), not the specific
# numeric address.
#
# Run with COCOTB_RESOLVE_X=ZEROS (e.g. `COCOTB_RESOLVE_X=ZEROS make`):
# the FFT core's internal buffers have no simulation init data (same as
# other BRAMs in this design), so they read back as Icarus 'x' until
# fully flushed by real data -- which takes longer than a single short
# integration epoch (see the nint=20 warm-up epoch in each test below).
# Without this, cocotb's AXI4Slave helper raises trying to interpret
# 'x' bits as a real memory write.
#
# Covers: (1) the pre-existing magnitude waterfall still works, (2)
# raw_capture actually works through the full Spectrometer wiring
# (previously only the bare Recorder16IQ was tested, never wired
# through Spectrometer), (3) the new continuous I/Q channel's cadence
# (one buffer per magnitude buffer) and bin-order consistency with the
# magnitude channel.

import struct

import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, with_timeout
from cocotb_bus.drivers import BitDriver

from axi import AXI4Slave
from backpressure import RandomReady
from memory import Memory

FFT_ORDER_LOG2 = 12
FFT_SIZE = 2**FFT_ORDER_LOG2

DMA_BUFFERS = 4       # matches DMA_BUFFERS_LOG2 in verilog.py
IQ_DMA_BUFFERS = 4    # matches IQ_DMA_BUFFERS_LOG2 in verilog.py

MAG_BUFFER_BYTES = FFT_SIZE * 8
IQ_BUFFER_BYTES = FFT_SIZE * 4
RAW_BYTES = FFT_SIZE * 4  # Recorder16IQ MODE_16BIT: 4 bytes/sample

# Large enough that after window attenuation and the extra 6-bit
# truncation (22-bit FFT output -> 16 bits for raw_capture/iq_dma) the
# resulting peak bin is still comfortably non-zero, not just
# "dominant" -- a small amplitude can truncate away to exactly zero.
DC_AMPLITUDE = 20000

# The two exact-comparison tests pass when each runs in its own simulation but
# fail with a content mismatch when they run after other tests in the same
# cocotb session (cause not found). They are skipped by default; `make exact`
# runs each one alone with this variable set.
EXACT = os.environ.get('SPECTROMETER_EXACT') == '1'

# cocotb's default test timeout is used via with_timeout below instead
# of a bare await, so a wiring mistake (e.g. an interrupt that never
# fires) fails the test instead of hanging the simulation forever.
TIMEOUT_NS = 2_000_000


def mag_decode(word):
    """Decode one 64-bit magnitude DMA word into an (unnormalized,
    monotonic) magnitude proxy. See Spectrometer.elaborate()'s
    dma_rdata Cat() for the exact bit layout this mirrors."""
    mantissa = word & ((1 << 47) - 1)
    exponent = (word >> 56) & 0b111
    return mantissa * (4 ** exponent)


def iq_decode(word):
    """Decode one 32-bit I/Q waterfall word: Q (im) in the low 16 bits,
    I (re) in the high 16 bits -- see Spectrometer.elaborate()'s
    iq_write_data Cat()."""
    q = struct.unpack('<h', struct.pack('<H', word & 0xffff))[0]
    i = struct.unpack('<h', struct.pack('<H', (word >> 16) & 0xffff))[0]
    return i, q


def read_bytes(mem, offset, n):
    """Read n bytes starting at offset, one byte at a time.

    Memory.__getitem__'s slice support wraps both start and stop via
    '% self._len' independently (it's designed for ring-buffer
    access), which breaks exactly when offset + n == len(mem): stop
    wraps to 0, producing an empty (or wrong) slice. Byte-at-a-time
    indexing uses the same wraparound per byte, which is harmless and
    gives the right bytes right up to (and past) that boundary.
    """
    return bytes(mem[offset + i] for i in range(n))


def raw_decode(mem, sample_index):
    """Decode one raw_capture sample: I (re) in the low 16 bits, Q (im)
    in the high 16 bits of each 32-bit little-endian group -- see
    Pack16IQto32's docstring (interleaved little-endian I/Q)."""
    offset = sample_index * 4
    i = struct.unpack('<h', read_bytes(mem, offset, 2))[0]
    q = struct.unpack('<h', read_bytes(mem, offset + 2, 2))[0]
    return i, q


def mag_word_at(mem, buffer_index, addr):
    offset = buffer_index * MAG_BUFFER_BYTES + addr * 8
    return struct.unpack('<Q', read_bytes(mem, offset, 8))[0]


def iq_word_at(mem, buffer_index, addr):
    offset = buffer_index * IQ_BUFFER_BYTES + addr * 4
    return struct.unpack('<I', read_bytes(mem, offset, 4))[0]


def find_peak(values):
    """Given a list of per-address magnitude-proxy values, return
    (peak_index, peak_value, median_value) -- median rather than mean
    or a fixed 'other' address, so a single stray large value
    elsewhere doesn't skew the dominance check."""
    peak_index = max(range(len(values)), key=lambda i: values[i])
    median_value = sorted(values)[len(values) // 2]
    return peak_index, values[peak_index], median_value


def mag_values(mem, buffer_index):
    return [mag_decode(mag_word_at(mem, buffer_index, addr))
            for addr in range(FFT_SIZE)]


def iq_values(mem, buffer_index):
    def pwr(addr):
        i, q = iq_decode(iq_word_at(mem, buffer_index, addr))
        return i * i + q * q
    return [pwr(addr) for addr in range(FFT_SIZE)]


def raw_values(mem):
    def pwr(idx):
        i, q = raw_decode(mem, idx)
        return i * i + q * q
    return [pwr(idx) for idx in range(FFT_SIZE)]


class SpectrometerTB:
    def __init__(self, dut):
        self.dut = dut
        self.mag_mem = Memory(DMA_BUFFERS * MAG_BUFFER_BYTES)
        self.raw_mem = Memory(RAW_BYTES)
        self.iq_mem = Memory(IQ_DMA_BUFFERS * IQ_BUFFER_BYTES)
        self.mag_axi = AXI4Slave(dut, 'DMA', dut.clk, self.mag_mem)
        self.raw_axi = AXI4Slave(dut, 'RAW', dut.clk, self.raw_mem)
        self.iq_axi = AXI4Slave(dut, 'IQ', dut.clk, self.iq_mem)

    def start_clocks(self):
        cocotb.start_soon(Clock(self.dut.clk, 12, units='ns').start())
        cocotb.start_soon(Clock(self.dut.clk2x_clk, 6, units='ns').start())
        cocotb.start_soon(Clock(self.dut.clk3x_clk, 4, units='ns').start())

    async def reset(self, nint=2, warmup=False):
        """warmup=True flushes the FFT core's internal butterfly-stage
        buffers before settling at the requested nint. Those buffers have
        no simulation init data (same as other BRAMs in this design, e.g.
        SpectrumIntegrator's own accumulator memories), so they read back
        as 'x' in Icarus until every address has been written at least
        once by real data flowing through -- which takes more cycles than
        a single short integration epoch, and does not happen just because
        rst was pulsed. Originally this was done once, by running
        test_magnitude_and_iq_channel first; any test run alone, or after
        a different predecessor, saw stale/'x' data instead. A test's own
        reset(warmup=True) makes it self-contained regardless of test
        order. SpectrumIntegrator restarts each new epoch's accumulation
        from a forced read_data=0 (see its not_first_sum_delay-gated Mux),
        so later epochs don't inherit the warmup epoch's content, only
        whatever settling it caused in the FFT core's own pipeline."""
        self.dut.rst.value = 1
        self.dut.abort.value = 0
        self.dut.peak_detect.value = 0
        self.dut.capture_start.value = 0
        self.dut.capture_stop.value = 0
        self.dut.fastlock_profile.value = 0
        self.dut.number_integrations.value = 20 if warmup else nint
        self.dut.re_in.value = 0
        self.dut.im_in.value = 0
        self.dut.strobe_in.value = 0
        await ClockCycles(self.dut.clk, 10)
        self.dut.rst.value = 0
        await ClockCycles(self.dut.clk, 2)
        if warmup:
            # Bounded (not fire-and-forget): one full nint=20 epoch plus a
            # small pipeline-latency margin, then join the task so no
            # driver is left running when reset() returns. A caller that
            # wants its own data for the real test starts its own drive_*
            # afterwards, exactly as it would without warmup -- it never
            # races against a lingering warmup driver.
            warmup_cycles = 20 * FFT_SIZE + 256
            drive_task = cocotb.start_soon(
                self.drive_dc(DC_AMPLITUDE, 0, warmup_cycles))
            await with_timeout(RisingEdge(self.dut.interrupt_out),
                               TIMEOUT_NS, 'ns')
            await with_timeout(RisingEdge(self.dut.iq_interrupt_out),
                               TIMEOUT_NS, 'ns')
            await drive_task
            # Do not deassert strobe_in here: drive_dc's docstring notes
            # the real design never sees strobe drop (it's driven
            # continuously from the sync domain). Leaving it latched at
            # its last warmup value for the cycle or two before the
            # caller's own drive_* takes over avoids a gap that the
            # design has never been exercised against.
            #
            # Also abort while changing number_integrations (as
            # test_abort_and_nint_change_sanity does): the integrator
            # only reloads sum_counter from the *current*
            # number_integrations at the next sum_counter==1 rollover,
            # which has already just happened (that rollover is what
            # made interrupt_out/iq_interrupt_out fire above) using the
            # *old* nint=20. Without abort, the new nint would not take
            # effect until one more full 20-frame epoch (~82000 cycles)
            # has passed, silently costing every caller that extra
            # epoch before their first real completion.
            rising = RisingEdge(self.dut.clk)
            await rising
            self.dut.abort.value = 1
            self.dut.number_integrations.value = nint
            await rising
            self.dut.abort.value = 0
            await rising

    async def drive_samples(self, re_list, im_list):
        """Drive one sample per clk cycle from the given lists (same pacing
        as drive_dc)."""
        rising = RisingEdge(self.dut.clk)
        for re, im in zip(re_list, im_list):
            await rising
            self.dut.strobe_in.value = 1
            self.dut.re_in.value = re & 0xffff
            self.dut.im_in.value = im & 0xffff

    async def drive_dc(self, re, im, cycles):
        """Continuously present a constant (DC) complex sample, one per
        'sync' (1x) clock cycle -- this is the pacing Spectrometer
        actually expects: strobe_in/re_in/im_in are only ever driven
        from 'sync'-domain registers in the real MaiaSDR top level
        (see spectrometer_strobe_in in maia_sdr.py), so from clk3x's
        perspective they are always held stable for exactly 3 clk3x
        cycles per new sample -- never toggled faster than that."""
        rising = RisingEdge(self.dut.clk)
        for _ in range(cycles):
            await rising
            self.dut.strobe_in.value = 1
            self.dut.re_in.value = re & 0xffff
            self.dut.im_in.value = im & 0xffff


@cocotb.test()
async def test_magnitude_and_iq_channel(dut):
    """Magnitude waterfall regression + new I/Q channel cadence and
    bin-order correctness."""
    tb = SpectrometerTB(dut)
    tb.start_clocks()
    # See SpectrometerTB.reset's docstring: flush the FFT core's internal
    # buffers before trusting any data, regardless of what (if anything)
    # ran before this test.
    await tb.reset(nint=2, warmup=True)

    cocotb.start_soon(tb.drive_dc(DC_AMPLITUDE, 0, 400_000))

    mag_interrupts = 0
    iq_interrupts = 0
    last_mag_buffer = None
    last_iq_buffer = None

    async def wait_mag():
        nonlocal mag_interrupts, last_mag_buffer
        await with_timeout(RisingEdge(dut.interrupt_out), TIMEOUT_NS, 'ns')
        mag_interrupts += 1
        last_mag_buffer = int(dut.last_buffer.value)

    async def wait_iq():
        nonlocal iq_interrupts, last_iq_buffer
        await with_timeout(
            RisingEdge(dut.iq_interrupt_out), TIMEOUT_NS, 'ns')
        iq_interrupts += 1
        last_iq_buffer = int(dut.iq_last_buffer.value)

    # Collect 3 epochs' worth of completions from each channel, now
    # that the FFT core's pipeline has settled and nint is back down.
    for _ in range(3):
        await wait_mag()
        await wait_iq()

    assert mag_interrupts == iq_interrupts == 3, (
        f'expected 1:1 cadence, got mag={mag_interrupts} '
        f'iq={iq_interrupts}')

    mag_peak_addr, mag_peak, mag_median = find_peak(
        mag_values(tb.mag_mem, last_mag_buffer))
    assert mag_peak > 1000 * max(mag_median, 1), (
        f'magnitude waterfall: expected a dominant DC peak, got '
        f'peak={mag_peak} at addr={mag_peak_addr}, median={mag_median}')

    iq_peak_addr, iq_peak_pwr, iq_median_pwr = find_peak(
        iq_values(tb.iq_mem, last_iq_buffer))
    assert iq_peak_pwr > 1000 * max(iq_median_pwr, 1), (
        f'I/Q channel: expected a dominant DC peak, got '
        f'peak_pwr={iq_peak_pwr} at addr={iq_peak_addr}, '
        f'median_pwr={iq_median_pwr}')

    # Load-bearing cross-check: both channels tap fft.re_out/im_out the
    # same way and apply the same bit-reversal+fftshift remap, so a
    # wiring mistake in either (e.g. the phase-shifted-counter bug this
    # design was deliberately built to avoid, see spectrometer.py's
    # iq_write_counter comment) would make them disagree on which
    # address the peak is at, even though each looks fine in isolation.
    assert mag_peak_addr == iq_peak_addr, (
        f'magnitude and I/Q channel disagree on peak bin: '
        f'mag addr={mag_peak_addr}, iq addr={iq_peak_addr}')


@cocotb.test()
async def test_raw_capture_through_spectrometer(dut):
    """raw_capture (Recorder16IQ) wired through the full Spectrometer,
    not just the bare module (which is already covered by
    test_cocotb/recorder). Confirms the tap/truncation/trigger wiring
    added in Spectrometer.elaborate() actually works end to end."""
    tb = SpectrometerTB(dut)
    tb.start_clocks()
    # See SpectrometerTB.reset's docstring: settle the FFT core's internal
    # buffers with one long epoch before trusting any data, so the
    # capture doesn't start on power-on-reset (or leftover) garbage.
    await tb.reset(nint=20, warmup=True)

    cocotb.start_soon(tb.drive_dc(DC_AMPLITUDE, 0, 400_000))

    rising = RisingEdge(dut.clk)
    await rising
    dut.capture_start.value = 1
    await rising
    dut.capture_start.value = 0

    await with_timeout(RisingEdge(dut.capture_finished), TIMEOUT_NS, 'ns')

    # Not asserting capture_dropped_samples == 0 here: cocotb's AXI4Slave
    # responder is not necessarily fast enough to drain Recorder16IQ's
    # CDC FIFO at full line rate the way a real AXI subordinate (DDR
    # controller) would -- a drop here reflects testbench throughput,
    # not a wiring bug. The content check below is what actually
    # exercises the tap/truncation/trigger wiring.
    peak_index, peak_pwr, median_pwr = find_peak(raw_values(tb.raw_mem))
    assert peak_pwr > 1000 * max(median_pwr, 1), (
        f'raw_capture: expected a dominant DC peak, got '
        f'peak_pwr={peak_pwr} at sample={peak_index}, '
        f'median_pwr={median_pwr}')


@cocotb.test()
async def test_raw_capture_strobe_is_single_pulse(dut):
    """The raw tap lives in the clk3x domain but strobe_in is a one-clk
    (sync) pulse, so it is seen for 3 clk3x cycles. Recorder16IQ must get
    exactly one strobe per sample: with strobe_in high every clk cycle,
    the raw capture strobe has to be high in one clk3x cycle per clk
    cycle, not in all three (which wrote every sample three times)."""
    tb = SpectrometerTB(dut)
    tb.start_clocks()
    await tb.reset(nint=20, warmup=True)
    cocotb.start_soon(tb.drive_dc(DC_AMPLITUDE, 0, 20_000))
    await ClockCycles(dut.clk, 200)

    core = dut.dut.spectrometer
    rising3x = RisingEdge(dut.clk3x_clk)
    n3x = 3 * 3000
    count = 0
    for _ in range(n3x):
        await rising3x
        count += int(core.raw_capture.strobe_in.value)
    assert abs(count - n3x // 3) <= 3, (
        f'raw capture strobe high in {count} of {n3x} clk3x cycles, '
        f'expected {n3x // 3} (one per clk cycle)')


@cocotb.test()
async def test_abort_and_nint_change_sanity(dut):
    """Sanity check (liveness, not bit-exact correctness) that both
    the magnitude and I/Q channels keep producing completions after an
    abort + number_integrations change mid-epoch -- the exact edge case
    end_fft/nearly_end's derivation (and hence this design's write
    enables) is already built to survive without extra state
    duplication; this proves it doesn't lock up."""
    tb = SpectrometerTB(dut)
    tb.start_clocks()
    await tb.reset(nint=4)

    cocotb.start_soon(tb.drive_dc(DC_AMPLITUDE, 0, 400_000))

    # Let one epoch complete normally first.
    await with_timeout(RisingEdge(dut.interrupt_out), TIMEOUT_NS, 'ns')

    # Abort mid-epoch and change nint.
    await ClockCycles(dut.clk, FFT_SIZE // 2)
    rising = RisingEdge(dut.clk)
    await rising
    dut.abort.value = 1
    dut.number_integrations.value = 2
    await rising
    dut.abort.value = 0

    # Both channels should keep completing afterwards.
    await with_timeout(RisingEdge(dut.interrupt_out), TIMEOUT_NS, 'ns')
    await with_timeout(RisingEdge(dut.iq_interrupt_out), TIMEOUT_NS, 'ns')
    await with_timeout(RisingEdge(dut.interrupt_out), TIMEOUT_NS, 'ns')
    await with_timeout(RisingEdge(dut.iq_interrupt_out), TIMEOUT_NS, 'ns')


@cocotb.test()
async def test_spectrometer_wready_backpressure(dut):
    """Random WREADY backpressure on all three AXI write ports
    (magnitude, raw, I/Q), checking the DMA write paths survive AXI
    stalls -- not just the always-ready cocotb AXI4Slave responder every
    other test in this file relies on.

    This directly targets a concern recorded in memory
    (project-pluto-webservice-test-step3): on hardware, the I/Q DMA
    read-back returns far fewer non-zero words than expected, suspected
    to be a stall-sensitivity in the tap/DMA write capture path that an
    always-ready simulated AXI slave would never exercise. It overrides
    AXI4Slave's own fixed WREADY=1 with a directly-driven BitDriver on
    each AXI port's WREADY pin, the same pattern test_cocotb/dma's own
    test_dma.py already uses to backpressure DmaBRAMWrite (the exact DMA
    write submodule the magnitude and I/Q paths both use)."""
    tb = SpectrometerTB(dut)
    tb.start_clocks()
    await tb.reset(nint=2, warmup=True)

    mag_backpressure = BitDriver(dut.DMA_WREADY, dut.clk)
    raw_backpressure = BitDriver(dut.RAW_WREADY, dut.clk)
    iq_backpressure = BitDriver(dut.IQ_WREADY, dut.clk)
    # Magnitude and I/Q DMAs run at about 75% ready. At 50% one DMA of 4096
    # words takes longer than a 2-frame epoch (8192 cycles), the next epoch's
    # DMA starts before it finishes and the two buffers legitimately disagree;
    # that is a property of this nint, not of the design.
    mag_backpressure.start(RandomReady(8, 2)())
    raw_backpressure.start(RandomReady(4, 4)())
    iq_backpressure.start(RandomReady(8, 2)())

    cocotb.start_soon(tb.drive_dc(DC_AMPLITUDE, 0, 400_000))

    # Backpressure slows the transfers; give completions more room than the
    # other tests' TIMEOUT_NS.
    backpressure_timeout = 4 * TIMEOUT_NS

    mag_interrupts = 0
    iq_interrupts = 0
    last_mag_buffer = None
    last_iq_buffer = None

    async def wait_mag():
        nonlocal mag_interrupts, last_mag_buffer
        await with_timeout(RisingEdge(dut.interrupt_out),
                           backpressure_timeout, 'ns')
        mag_interrupts += 1
        last_mag_buffer = int(dut.last_buffer.value)

    async def wait_iq():
        nonlocal iq_interrupts, last_iq_buffer
        await with_timeout(
            RisingEdge(dut.iq_interrupt_out), backpressure_timeout, 'ns')
        iq_interrupts += 1
        last_iq_buffer = int(dut.iq_last_buffer.value)

    for _ in range(2):
        await wait_mag()
        await wait_iq()

    assert mag_interrupts == iq_interrupts == 2, (
        f'expected 1:1 cadence under backpressure, got '
        f'mag={mag_interrupts} iq={iq_interrupts}')

    mag_peak_addr, mag_peak, mag_median = find_peak(
        mag_values(tb.mag_mem, last_mag_buffer))
    assert mag_peak > 1000 * max(mag_median, 1), (
        f'magnitude waterfall under backpressure: expected a dominant DC '
        f'peak, got peak={mag_peak} at addr={mag_peak_addr}, '
        f'median={mag_median}')

    iq_peak_addr, iq_peak_pwr, iq_median_pwr = find_peak(
        iq_values(tb.iq_mem, last_iq_buffer))
    assert iq_peak_pwr > 1000 * max(iq_median_pwr, 1), (
        f'I/Q channel under backpressure: expected a dominant DC peak, '
        f'got peak_pwr={iq_peak_pwr} at addr={iq_peak_addr}, '
        f'median_pwr={iq_median_pwr}')

    assert mag_peak_addr == iq_peak_addr, (
        f'magnitude and I/Q channel disagree on peak bin under '
        f'backpressure: mag addr={mag_peak_addr}, iq addr={iq_peak_addr}')

    # Also exercise raw_capture under the same backpressure.
    rising = RisingEdge(dut.clk)
    await rising
    dut.capture_start.value = 1
    await rising
    dut.capture_start.value = 0
    await with_timeout(
        RisingEdge(dut.capture_finished), backpressure_timeout, 'ns')
    raw_peak_index, raw_peak_pwr, raw_median_pwr = find_peak(
        raw_values(tb.raw_mem))
    assert raw_peak_pwr > 1000 * max(raw_median_pwr, 1), (
        f'raw_capture under backpressure: expected a dominant DC peak, '
        f'got peak_pwr={raw_peak_pwr} at sample={raw_peak_index}, '
        f'median_pwr={raw_median_pwr}')


@cocotb.test(skip=not EXACT)
async def test_iq_and_magnitude_exact(dut):
    """Exact check against the recorded FFT stream (nint=2): the magnitude
    buffer equals the sum of two frames' |X|^2 and the I/Q buffer holds the
    last frame (re >> 6, im >> 6), both at the bit-reversed address."""
    await _check_iq_and_magnitude_exact(dut, seed=9, n=60_000)


@cocotb.test(skip=not EXACT)
async def test_iq_and_magnitude_exact_backpressure(dut):
    """Same exact check as test_iq_and_magnitude_exact, with random WREADY
    backpressure on the magnitude and I/Q DMA write ports."""
    await _check_iq_and_magnitude_exact(
        dut, seed=9, n=600_000, backpressure=True)


async def _check_iq_and_magnitude_exact(dut, seed, n, backpressure=False):
    """Exact check against the recorded FFT stream. With nint=2 each epoch
    ends on a frame boundary. The magnitude buffer must equal the sum of the
    two frames' |X|^2, and the I/Q buffer must equal the last frame's
    (re >> 6, im >> 6), both at address INV[a] (the bit-reversed counter map).
    Note: with nint=1 the I/Q tap never writes (nearly_end needs sum_counter
    == 2), so this test uses nint=2."""
    import numpy as np
    tb = SpectrometerTB(dut)
    tb.start_clocks()
    # See SpectrometerTB.reset's docstring: this check is exact, so it
    # needs the FFT core's buffers flushed first, regardless of what
    # (if anything) ran before this test.
    await tb.reset(nint=2, warmup=True)
    if backpressure:
        # Random WREADY stalls on both DMA write ports, instead of the
        # always-ready AXI4Slave.
        for wready in (dut.DMA_WREADY, dut.IQ_WREADY):
            BitDriver(wready, dut.clk).start(RandomReady(8, 2)())
    rng = np.random.default_rng(seed)
    re = rng.integers(-8000, 8000, n)
    im = rng.integers(-8000, 8000, n)
    cocotb.start_soon(tb.drive_samples(re.tolist(), im.tolist()))

    core = dut.dut.spectrometer
    s_re, s_im, s_last = [], [], []
    mag_done, iq_done = [], []
    rising = RisingEdge(dut.clk)
    for _ in range(n):
        await rising
        if int(core.strobe_in.value):
            s_re.append(int(core.re_out.value.signed_integer))
            s_im.append(int(core.im_out.value.signed_integer))
            s_last.append(int(core.out_last.value))
        if int(dut.interrupt_out.value):
            mag_done.append((len(s_re), int(dut.last_buffer.value),
                             [mag_word_at(tb.mag_mem,
                                          int(dut.last_buffer.value), a)
                              for a in range(FFT_SIZE)]))
        if int(dut.iq_interrupt_out.value):
            b = int(dut.iq_last_buffer.value)
            iq_done.append((len(s_re), b,
                            [iq_word_at(tb.iq_mem, b, a)
                             for a in range(FFT_SIZE)]))
        if len(mag_done) >= 4 and len(iq_done) >= 4:
            break

    b_order = 12

    def shift(c):
        r = [(c >> i) & 1 for i in range(b_order)][::-1]
        r = r[:-1] + [1 - r[-1]]
        return sum(bit << i for i, bit in enumerate(r))
    inv = np.empty(FFT_SIZE, dtype=int)
    inv[np.array([shift(c) for c in range(FFT_SIZE)])] = np.arange(FFT_SIZE)
    sr = np.array(s_re, dtype=np.int64)
    si = np.array(s_im, dtype=np.int64)
    ends = [i for i, v in enumerate(s_last) if v]

    def frame(fe):
        return sr[fe - FFT_SIZE + 1: fe + 1], si[fe - FFT_SIZE + 1: fe + 1]

    def s16(v):
        v = v & 0xffff
        return v - 0x10000 if v >= 0x8000 else v

    # A stalled DMA completes several frames after its epoch ended.
    lookback = 10 if backpressure else 4
    checked_mag = checked_iq = 0
    for at, _, words in mag_done[1:]:
        mant = np.array([w & ((1 << 47) - 1) for w in words], dtype=float)
        exp = np.array([(w >> 56) & 7 for w in words], dtype=float)
        got = mant * 4.0 ** exp
        if got.max() == 0:
            continue
        ok = False
        for fe in [e for e in ends
                   if e < at and e >= 2 * FFT_SIZE][-lookback:]:
            r1, i1 = frame(fe)
            r0, i0 = frame(fe - FFT_SIZE)
            pred = ((r1 ** 2 + i1 ** 2) + (r0 ** 2 + i0 ** 2))[inv]
            if np.corrcoef(np.argsort(np.argsort(got)),
                           np.argsort(np.argsort(pred)))[0, 1] > 0.999:
                ok = True
                break
        assert ok, (f'magnitude completed at stream {at} matches no recent '
                    f'two-frame sum')
        checked_mag += 1

    for at, _, words in iq_done[1:]:
        if all(w == 0 for w in words):
            continue
        ok = False
        for fe in [e for e in ends if e < at and e >= FFT_SIZE][-lookback:]:
            r, i = frame(fe)
            pos = set(zip((r >> 6).tolist(), (i >> 6).tolist()))
            pairs = [(s16(w >> 16), s16(w)) for w in words]
            hits = sum(1 for p in [pairs[a] for a in range(FFT_SIZE)]
                       if p in pos)
            if hits == FFT_SIZE:
                ok = True
                break
        assert ok, (f'I/Q buffer completed at stream {at} matches no recent '
                    f'frame (shift 6)')
        checked_iq += 1

    assert checked_mag >= 2 and checked_iq >= 2, (
        f'too few completions checked: mag={checked_mag} iq={checked_iq}')
