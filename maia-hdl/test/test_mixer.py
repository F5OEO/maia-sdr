#
# Copyright (C) 2024 Daniel Estevez <daniel@destevez.net>
#
# This file is part of maia-sdr
#
# SPDX-License-Identifier: MIT
#

from amaranth import *
import numpy as np

import unittest

from maia_hdl.mixer import Mixer
from .amaranth_sim import AmaranthSim
from .common_edge import CommonEdgeTb


class TestMixer(AmaranthSim):
    def test_mixer(self):
        domain_3x = 'clk3x'
        width = 16
        mixer = Mixer(domain_3x, width)
        freq = round(0.01 * 2**mixer.nco_width)
        self.dut = CommonEdgeTb(
            mixer, [(domain_3x, 3, 'common_edge')])
        num_inputs = 1000
        re, im = [np.random.randint(-2**(width - 1), 2**(width - 1),
                                    size=num_inputs)
                  for _ in range(2)]
        # skip the first few output samples, because the BRAM
        # pipeline is not loaded yet
        skip = 2
        expected_re, expected_im = mixer.model(freq, re[skip:], im[skip:])
        go_back = mixer.delay + skip

        async def bench(ctx):
            for j in range(num_inputs):
                await ctx.tick()
                ctx.set(mixer.clken, 1)
                ctx.set(mixer.frequency, freq)
                ctx.set(mixer.re_in, int(re[j]))
                ctx.set(mixer.im_in, int(im[j]))
                if j >= go_back:
                    out = (
                        ctx.get(mixer.re_out)
                        + 1j * ctx.get(mixer.im_out))
                    expected = (expected_re[j - go_back]
                                + 1j * expected_im[j - go_back])
                    assert out == expected, \
                        f'out = {out}, expected = {expected} @ cycle = {j}'

        self.simulate(bench, named_clocks={domain_3x: 4e-9})

    def test_mixer_full_scale_no_wrap(self):
        # With out_width = width + 1 a rotated full-scale input does not
        # wrap: the output stays within rounding of the exact rotation.
        domain_3x = 'clk3x'
        width = 12
        mixer = Mixer(domain_3x, width, out_width=width + 1)
        freq = round(0.0123 * 2**mixer.nco_width)
        self.dut = CommonEdgeTb(
            mixer, [(domain_3x, 3, 'common_edge')])
        num_inputs = 1000
        re, im = [np.random.randint(-2**(width - 1), 2**(width - 1),
                                    size=num_inputs)
                  for _ in range(2)]
        re[::7] = -2**(width - 1)
        im[::7] = -2**(width - 1)
        skip = 2
        expected_re, expected_im = mixer.model(freq, re[skip:], im[skip:])
        # exact rotation by the same lookup table phases
        phase = (np.arange(len(re) - skip) * freq) % 2**mixer.nco_width
        phase //= 2**(mixer.nco_width - mixer.phase_bits)
        n = 2**mixer.phase_bits
        exact = ((re[skip:] + 1j * im[skip:])
                 * np.exp(-1j * 2 * np.pi * phase / n))
        err = np.abs(expected_re - exact.real) + \
            np.abs(expected_im - exact.imag)
        assert np.max(err) < 3, np.max(err)
        assert np.max(np.abs(exact.real)) > 2**(width - 1), \
            'test needs > 12-bit outputs'
        go_back = mixer.delay + skip

        async def bench(ctx):
            for j in range(num_inputs):
                await ctx.tick()
                ctx.set(mixer.clken, 1)
                ctx.set(mixer.frequency, freq)
                ctx.set(mixer.re_in, int(re[j]))
                ctx.set(mixer.im_in, int(im[j]))
                if j >= go_back:
                    out = (
                        ctx.get(mixer.re_out)
                        + 1j * ctx.get(mixer.im_out))
                    expected = (expected_re[j - go_back]
                                + 1j * expected_im[j - go_back])
                    assert out == expected, \
                        f'out = {out}, expected = {expected} @ cycle = {j}'

        self.simulate(bench, named_clocks={domain_3x: 4e-9})


if __name__ == '__main__':
    unittest.main()
