#!/usr/bin/env python3
#
# Copyright (C) 2026 Daniel Estevez <daniel@destevez.net>
#
# This file is part of maia-sdr
#
# SPDX-License-Identifier: MIT
#

from amaranth import *
from amaranth.back.verilog import convert

from maia_hdl.clknx import ClkNxCommonEdge
from maia_hdl.spectrometer import Spectrometer

# Small buffer counts to keep simulation fast -- this test cares about
# address sequencing and bin ordering, not about exercising a realistic
# number of ring-buffer slots.
DMA_BUFFERS_LOG2 = 2
IQ_DMA_BUFFERS_LOG2 = 2


class SpectrometerTestTop(Elaboratable):
    """Wraps Spectrometer together with the ClkNxCommonEdge generators
    that a real top-level (MaiaSDR) would normally provide, so this can
    be driven directly from a single 'sync' clock in simulation (clk2x
    and clk3x are then free-running, phase-aligned multiples of it, with
    common_edge_2x/3x generated for real instead of being hand-faked by
    the testbench).
    """
    def __init__(self):
        self.spectrometer = Spectrometer(
            0x0000_0000, DMA_BUFFERS_LOG2, dma_name='dma',
            raw_dma_base_address=0x1000_0000,
            raw_dma_end_address=0x1000_4000,
            raw_dma_domain_dma='sync',
            iq_dma_base_address=0x2000_0000,
            iq_dma_buffers_log2=IQ_DMA_BUFFERS_LOG2)

    def ports(self):
        s = self.spectrometer
        return [
            s.strobe_in, s.re_in, s.im_in,
            s.number_integrations, s.abort, s.peak_detect,
            s.last_buffer, s.interrupt_out, s.fastlock_profile,
            s.end_fft,
            s.capture_start, s.capture_stop, s.capture_finished,
            s.capture_dropped_samples, s.capture_next_address,
            s.iq_last_buffer, s.iq_interrupt_out,
            ClockSignal('clk2x'), ClockSignal('clk3x'),
        ] + s.dma.axi.ports() + s.raw_capture.dma.axi.ports() \
          + s.iq_dma.axi.ports()

    def elaborate(self, platform):
        m = Module()
        m.domains += [ClockDomain('clk2x'), ClockDomain('clk3x')]

        m.submodules.common_edge_2x = common_edge_2x = ClkNxCommonEdge(
            'sync', 'clk2x', 2)
        m.submodules.common_edge_3x = common_edge_3x = ClkNxCommonEdge(
            'sync', 'clk3x', 3)
        m.submodules.spectrometer = s = self.spectrometer

        m.d.comb += [
            s.common_edge_2x.eq(common_edge_2x.common_edge),
            s.common_edge_3x.eq(common_edge_3x.common_edge),
        ]

        return m


def main():
    top = SpectrometerTestTop()
    with open('dut.v', 'w') as f:
        f.write('`timescale 1ps/1ps\n')
        f.write(convert(
            top, name='dut', ports=top.ports(), emit_src=False))


if __name__ == '__main__':
    main()
