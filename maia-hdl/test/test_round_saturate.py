#
# Copyright (C) 2026 Mario Behn <mario.behn@gmail.com>
#
# This file is part of maia-sdr
#
# SPDX-License-Identifier: MIT
#

from amaranth import *
from amaranth.sim import Simulator
import numpy as np

import unittest

from maia_hdl.round_saturate import RoundSaturate


class TestRoundSaturate(unittest.TestCase):
    def simulate(self, bench):
        # RoundSaturate is combinational, so there is no clock to add
        sim = Simulator(self.dut)
        sim.add_testbench(bench)
        sim.run()

    def check(self, in_width, shift, out_width, values):
        self.dut = RoundSaturate(in_width, shift, out_width)
        x = np.asarray(values, dtype=np.int64)
        # model: round half to even (numpy rint), then saturate
        expected = np.clip(np.rint(x / 2**shift), -2**(out_width - 1),
                           2**(out_width - 1) - 1).astype(int)

        async def bench(ctx):
            for v, e in zip(x, expected):
                ctx.set(self.dut.x, int(v))
                assert ctx.get(
                    self.dut.y) == e, (int(v), ctx.get(
                        self.dut.y), int(e))

        self.simulate(bench)

    def test_all_16bit_values(self):
        # the DDC output to IIO: 16 bits -> 12 bits
        self.check(16, 4, 12, range(-2**15, 2**15))

    def test_saturation(self):
        # a narrower output that the rounded value can exceed
        self.check(8, 2, 5, range(-128, 128))

    def test_no_bias(self):
        # over a full period of every LSB pattern the mean error is zero
        self.dut = RoundSaturate(16, 4, 12)
        x = np.arange(-2**14, 2**14)
        err = []

        async def bench(ctx):
            for v in x:
                ctx.set(self.dut.x, int(v))
                err.append(ctx.get(self.dut.y) - v / 16)

        self.simulate(bench)
        assert abs(np.mean(err)) < 1e-9, np.mean(err)


if __name__ == '__main__':
    unittest.main()
