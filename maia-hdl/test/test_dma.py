#
# Copyright (C) 2022-2024 Daniel Estevez <daniel@destevez.net>
#
# This file is part of maia-sdr
#
# SPDX-License-Identifier: MIT
#

import unittest

from maia_hdl.dma import DmaBRAMWrite
from .amaranth_sim import AmaranthSim


class TestDmaBRAMWriteAddress(AmaranthSim):
    """Checks the AXI write addresses of DmaBRAMWrite for each data width.

    The cocotb DMA test only covers 64-bit words, and the address of the
    32-bit variant used to come out shifted by one bit."""

    def check_addresses(self, axi_width, base_address, num_buffers_log2=3,
                        bram_awidth=12):
        self.dut = DmaBRAMWrite(base_address, num_buffers_log2, bram_awidth,
                                axi_width=axi_width)
        burst_bytes = 16 * (axi_width // 8)
        buffer_bytes = (2**bram_awidth) * (axi_width // 8)
        num_bursts = (2**num_buffers_log2) * buffer_bytes // burst_bytes
        addresses = []

        async def bench(ctx):
            ctx.set(self.dut.axi.awready, 1)
            while len(addresses) < num_bursts + 2:
                await ctx.tick()
                if ctx.get(self.dut.axi.awvalid):
                    addresses.append(ctx.get(self.dut.axi.awaddr))

        self.simulate(bench)
        expected = [base_address
                    + (j * burst_bytes) % ((2**num_buffers_log2)
                                           * buffer_bytes)
                    for j in range(len(addresses))]
        self.assertEqual(addresses, expected)

    def test_address_64bit(self):
        self.check_addresses(64, 0x16000000, bram_awidth=12)

    def test_address_32bit(self):
        self.check_addresses(32, 0x1a200000, bram_awidth=12)

    def test_address_32bit_other_base(self):
        self.check_addresses(32, 0x00060000, bram_awidth=12)


if __name__ == '__main__':
    unittest.main()
