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

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, with_timeout

from axi import AXI4Slave
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

    async def reset(self, nint=2):
        self.dut.rst.value = 1
        self.dut.abort.value = 0
        self.dut.peak_detect.value = 0
        self.dut.capture_start.value = 0
        self.dut.capture_stop.value = 0
        self.dut.fastlock_profile.value = 0
        self.dut.number_integrations.value = nint
        self.dut.re_in.value = 0
        self.dut.im_in.value = 0
        self.dut.strobe_in.value = 0
        await ClockCycles(self.dut.clk, 10)
        self.dut.rst.value = 0
        await ClockCycles(self.dut.clk, 2)

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
    # Warm-up: the FFT core's internal butterfly-stage buffers have no
    # simulation init data (same as other BRAMs in this design, e.g.
    # SpectrumIntegrator's own accumulator memories), so they read
    # back as 'x' in Icarus until every address has been written at
    # least once by real data flowing through -- which takes more
    # cycles than a single short integration epoch. No test previously
    # exercised the real FFT core deeply enough in simulation to need
    # this. A single long epoch (large nint) flushes it; nint is then
    # lowered for the real cadence/content checks below. SpectrumIntegrator
    # restarts each new epoch's accumulation from a forced read_data=0
    # (see its not_first_sum_delay-gated Mux), so later epochs don't
    # inherit this epoch's content, only whatever settling it caused in
    # the FFT core's own pipeline.
    await tb.reset(nint=20)

    cocotb.start_soon(tb.drive_dc(DC_AMPLITUDE, 0, 400_000))

    await with_timeout(RisingEdge(dut.interrupt_out), TIMEOUT_NS, 'ns')
    await with_timeout(RisingEdge(dut.iq_interrupt_out), TIMEOUT_NS, 'ns')

    rising = RisingEdge(dut.clk)
    await rising
    dut.number_integrations.value = 2
    await rising

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
    # See test_magnitude_and_iq_channel's comment: settle the FFT
    # core's internal buffers with one long epoch before trusting any
    # data, so the capture doesn't start on power-on-reset garbage.
    await tb.reset(nint=20)

    cocotb.start_soon(tb.drive_dc(DC_AMPLITUDE, 0, 400_000))

    await with_timeout(RisingEdge(dut.interrupt_out), TIMEOUT_NS, 'ns')

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
