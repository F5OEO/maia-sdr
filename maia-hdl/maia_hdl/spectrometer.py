#
# Copyright (C) 2022-2024 Daniel Estevez <daniel@destevez.net>
#
# This file is part of maia-sdr
#
# SPDX-License-Identifier: MIT
#

from amaranth import *
import amaranth.back.verilog
import numpy as np

from .dma import DmaBRAMWrite
from .fft import FFT
from .recorder import Recorder16IQ, RecorderMode
from .spectrum_integrator import SpectrumIntegrator


class Spectrometer(Elaboratable):
    """Spectrometer

    This elaboratable uses an FFT and a spectrum integrator to compute
    waterfall data. The data is written to an AXI bus using a DMA
    (DMABramWrite).

    Optionally, it also exposes a raw complex FFT capture path: a
    ``Recorder16IQ`` tapped directly off the FFT output (``fft.re_out``/
    ``fft.im_out``, truncated to 16 bits), before the spectrum integrator
    discards phase. This is a triggered, single-shot capture (sized by
    ``raw_dma_base_address``/``raw_dma_end_address``), not a continuous
    feed -- full-rate per-frame complex output is far higher volume than
    the integrated/averaged waterfall, which is what makes the waterfall's
    continuous streaming sustainable in the first place. Pass
    ``raw_dma_base_address=None`` (the default) to omit this path entirely.

    Parameters
    ----------
    dma_base_address : int
        Base address for the DMABramWrite.
    dma_buffers_log2 : int
        Log2 of the number of DMA buffers, used as a parameter for
        the DMABramWrite.
    dma_name : Optional[str]
        DMA name. Used as the name for the DMABramWrite.
    domain_2x : str
        Name of the clock domain of the 2x clock.
    domain_3x : str
        Name of the clock domain of the 2x clock.
    raw_dma_base_address : Optional[int]
        Start address for the raw complex capture's DmaStreamWrite. If
        None (the default), the raw capture path is not instantiated.
    raw_dma_end_address : Optional[int]
        End address for the raw complex capture's DmaStreamWrite. Required
        if raw_dma_base_address is given.
    raw_dma_domain_dma : str
        Clock domain for the raw complex capture's DMA and control
        interface (the Recorder16IQ's domain_dma). Defaults to 'sync';
        pass the domain of whatever register file will drive
        capture_start/capture_stop and read capture_finished/
        capture_next_address, to avoid needing a separate CDC for those.

    Attributes
    ----------
    strobe_in : Signal(), in
        Strobe in for the input IQ samples.
    common_edge_2x : Signal(), in
        A signal that toggles with the 2x clock and is high immediately
        after the rising edge of the 1x clock.
    common_edge_3x : Signal(), in
        A signal that changes with the 3x clock and is high on the cycles
        immediately after the rising edge of the 1x clock. This is only
        present when cmult3x is enabled.
    re_in : Signal(signed(16)), in
        Input samples real part.
    im_in : Signal(signed(16)), in
        Input samples imaginary part.
    number_integrations : Signal(10), in
        Sets the number of integrations to use in the integrator.
    abort : Signal(), in
        Abort signal for the integrator. Used to finish the current
        integration prematurely.
    peak_detect : Signal(), in
        Enables peak detect mode (instead of average power mode).
    last_buffer : Signal(dma_buffers_log2), out
        Indicates the last buffer to which the DMA has written to.
    interrupt_out : Signal(), out
        Pulsed each time that a DMA transfer finishes.
    capture_start : Signal(), in
        Only present when the raw capture path is enabled. Pulse to start
        a single-shot raw complex FFT capture. See Recorder16IQ.start.
    capture_stop : Signal(), in
        Only present when the raw capture path is enabled. See
        Recorder16IQ.stop.
    capture_finished : Signal(), out
        Only present when the raw capture path is enabled. See
        Recorder16IQ.finished.
    capture_dropped_samples : Signal(), out
        Only present when the raw capture path is enabled. See
        Recorder16IQ.dropped_samples.
    capture_next_address : Signal(), out
        Only present when the raw capture path is enabled. See
        Recorder16IQ.next_address.
    """
    def __init__(self, dma_base_address, dma_buffers_log2, dma_name=None,
                 domain_2x='clk2x', domain_3x='clk3x',
                 raw_dma_base_address=None, raw_dma_end_address=None,
                 raw_dma_domain_dma='sync'):
        self._domain_2x = domain_2x
        self._domain_3x = domain_3x
        self.fft_order_log2 = 12
        self.width_in = 16

        self.nint_width = 10

        self.dma = DmaBRAMWrite(
            dma_base_address, dma_buffers_log2,
            self.fft_order_log2, name=dma_name)

        self.strobe_in = Signal()
        self.common_edge_2x = Signal()
        self.common_edge_3x = Signal()
        self.re_in = Signal(signed(self.width_in))
        self.im_in = Signal(signed(self.width_in))

        self.number_integrations = Signal(self.nint_width)
        self.abort = Signal()
        self.peak_detect = Signal()
        self.last_buffer = Signal(dma_buffers_log2)

        self.interrupt_out = Signal()
        self.end_fft = Signal()
        self.fastlock_profile = Signal(3)

        self.raw_capture = None
        if raw_dma_base_address is not None:
            if raw_dma_end_address is None:
                raise ValueError(
                    'raw_dma_end_address is required when '
                    'raw_dma_base_address is given')
            raw_dma_name = f'{dma_name}_raw' if dma_name else None
            self.raw_capture = Recorder16IQ(
                raw_dma_base_address, raw_dma_end_address,
                dma_name=raw_dma_name,
                domain_in=self._domain_3x, domain_dma=raw_dma_domain_dma)
            self.capture_start = Signal()
            self.capture_stop = Signal()
            self.capture_finished = Signal()
            self.capture_dropped_samples = Signal()
            self.capture_next_address = Signal(
                len(self.raw_capture.next_address))

    def ports(self):
        ports = self.dma.axi.ports() + [
            self.strobe_in,
            self.common_edge_2x,
            self.common_edge_3x,
            self.re_in,
            self.im_in,
            self.number_integrations,
            self.abort,
            self.last_buffer,
            self.interrupt_out,
            self.fastlock_profile,
            self.end_fft,
        ]
        if self.raw_capture is not None:
            ports += [
                self.capture_start,
                self.capture_stop,
                self.capture_finished,
                self.capture_dropped_samples,
                self.capture_next_address,
            ] + self.raw_capture.dma.axi.ports()
        return ports

    def elaborate(self, platform):
        m = Module()

        truncates = [[0, 1]] * (self.fft_order_log2 // 2)
        m.submodules.fft = fft = FFT(
            self.width_in, self.fft_order_log2, 'R22',
            width_twiddle=16, truncates=truncates,
            use_bram_reg=True, window='blackmanharris',
            cmult3x=True,
            domain_2x=self._domain_2x, domain_3x=self._domain_3x)
        width_fft_out = len(fft.re_out)
        assert width_fft_out == 22

        spectrum_fp_width = 18
        m.submodules.integrator = integrator = SpectrumIntegrator(
            self._domain_3x, width_fft_out, spectrum_fp_width,
            self.nint_width, self.fft_order_log2)
        # Form 64-bit rdata for the DMA. The exponent is placed in the 8 MSBs
        # and the value is placed in the LSBs, leaving a gap with zeros between
        # them
        dma_rdata = Cat(integrator.rdata_value,
                        Const(0, 64 - 8 - len(integrator.rdata_value)),
                        integrator.rdata_exponent,
                        Const(0, 8 - len(integrator.rdata_exponent)-3),
                        self.fastlock_profile)
        assert len(integrator.rdata_value) == 47
        assert len(integrator.rdata_exponent) == 3
        assert len(dma_rdata) == 64

        m.submodules.dma = dma = self.dma

        dma_busy_q = Signal()
        m.d.sync += dma_busy_q.eq(dma.busy)

        m.d.comb += [
            fft.clken.eq(self.strobe_in),
            fft.common_edge_2x.eq(self.common_edge_2x),
            fft.common_edge_3x.eq(self.common_edge_3x),
            fft.re_in.eq(self.re_in),
            fft.im_in.eq(self.im_in),

            integrator.nint.eq(self.number_integrations),
            integrator.abort.eq(self.abort),
            integrator.peak_detect.eq(self.peak_detect),
            integrator.clken.eq(self.strobe_in),
            integrator.common_edge.eq(self.common_edge_3x),
            integrator.input_last.eq(fft.out_last),
            integrator.re_in.eq(fft.re_out),
            integrator.im_in.eq(fft.im_out),
            integrator.rdaddr.eq(dma.raddr),
            integrator.rden.eq(dma.ren),

            dma.rdata.eq(dma_rdata),
            dma.start.eq(integrator.done),
            self.last_buffer.eq(dma.last_buffer),
   #         self.end_fft.eq(integrator.done), 
            self.end_fft.eq(integrator.nearly_end), 
            self.interrupt_out.eq(~dma.busy & dma_busy_q),

        ]

        if self.raw_capture is not None:
            m.submodules.raw_capture = raw_capture = self.raw_capture
            # Truncate the FFT's 22-bit complex output to the 16 bits
            # Recorder16IQ expects, tapping it before the spectrum
            # integrator's CpwrPeak stage discards phase. Same domain_3x
            # assumption the integrator itself already makes for fft.re_out/
            # im_out (no explicit CDC there either).
            trunc = width_fft_out - self.width_in
            m.d.comb += [
                raw_capture.re_in.eq(fft.re_out >> trunc),
                raw_capture.im_in.eq(fft.im_out >> trunc),
                raw_capture.strobe_in.eq(self.strobe_in),
                raw_capture.mode.eq(RecorderMode.MODE_16BIT),
                raw_capture.start.eq(self.capture_start),
                raw_capture.stop.eq(self.capture_stop),
                self.capture_finished.eq(raw_capture.finished),
                self.capture_dropped_samples.eq(raw_capture.dropped_samples),
                self.capture_next_address.eq(raw_capture.next_address),
            ]

        return m


if __name__ == '__main__':
    spectrometer = Spectrometer(0x1000_0000, 5)
    amaranth.cli.main(
        spectrometer, ports=spectrometer.ports())
