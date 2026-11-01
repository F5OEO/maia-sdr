#
# Copyright (C) 2026 Yves Petit F4HSL
#
# SPDX-License-Identifier: MIT
#
"""SymFront against its bit-exact model (symfront_model.py).

Without SYMFRONT_CS8 the input is a synthetic QPSK signal (RRC, 2 - 4 samples
per symbol, carrier and clock offsets, noise). With SYMFRONT_CS8=<file> a
recording (e.g. from `zynqrx gen ... --prefiltered`) is used instead.
"""

import os
import random
import unittest

import numpy as np

from .amaranth_sim import AmaranthSim
from maia_hdl.symfront import SymFront, SymFrontIP
from amaranth.sim import Simulator
from maia_hdl import symfront_model as M


def synthetic(n_sym, sps=2.0003, cfo=0.0125, snr_db=12, seed=1):
    rng = np.random.default_rng(seed)
    sym = (rng.integers(0, 2, n_sym) * 2 - 1 + 1j * (rng.integers(0, 2, n_sym) * 2 - 1)) / np.sqrt(2)
    span = 8
    tt = np.arange(-span * 8, span * 8 + 1) / 8
    a = 0.35
    with np.errstate(divide='ignore', invalid='ignore'):
        h = (np.sin(np.pi * tt * (1 - a)) + 4 * a * tt * np.cos(np.pi * tt * (1 + a))) / (np.pi * tt * (1 - (4 * a * tt) ** 2))
    h[np.isclose(tt, 0)] = 1 - a + 4 * a / np.pi
    h[np.isnan(h)] = a / np.sqrt(2) * ((1 + 2 / np.pi) * np.sin(np.pi / (4 * a)) + (1 - 2 / np.pi) * np.cos(np.pi / (4 * a)))
    up = np.zeros(n_sym * 8, complex)
    up[::8] = sym
    x = np.convolve(up, h)
    x = np.convolve(x, h) / np.sum(h ** 2)
    idx = np.arange(0, len(x) - 8, 8 / sps)   # x has 8 points per symbol
    y = np.interp(idx, np.arange(len(x)), x.real) + 1j * np.interp(idx, np.arange(len(x)), x.imag)
    y = y * np.exp(2j * np.pi * cfo * np.arange(len(y)))
    y += (rng.standard_normal(len(y)) + 1j * rng.standard_normal(len(y))) * 10 ** (-snr_db / 20) / 2
    y = np.round(y * 600)
    return [(int(r), int(i)) for r, i in zip(y.real, y.imag)]


class TestSymFront(AmaranthSim):
    def setUp(self):
        self.dut = SymFront()

    def test_against_model(self):
        self.run_model_check(0)

    def test_sps_2667(self):
        self.run_model_check(M.sps_word(8 / 3), 8 / 3 * 1.00015)

    def test_sps_4(self):
        self.run_model_check(M.sps_word(4.0), 4.0006)

    def run_model_check(self, sps_reg, sps_signal=2.0003):
        path = os.environ.get('SYMFRONT_CS8')
        if path:
            raw = np.fromfile(path, dtype=np.int8).astype(int) * 16
            n = int(os.environ.get('SYMFRONT_SAMPLES', '40000'))
            x = list(zip(raw[0:2 * n:2].tolist(), raw[1:2 * n:2].tolist()))
            cfo = float(os.environ.get('SYMFRONT_CFO', '0')) / float(os.environ.get('SYMFRONT_FS', '2e6'))
        else:
            x = synthetic(6000 if sps_reg == 0 else 3000, sps=sps_signal)
            cfo = 0.0125 * 2 / sps_signal
        step = M.nco_step(cfo, 1.0)
        kp, ki = M.loop_gains(0.02)
        model = M.SymFrontModel(step, kp, ki, sps_reg)
        expected = model.process(x)
        got = []
        done = []

        async def drive(ctx):
            ctx.set(self.dut.nco_step, step)
            ctx.set(self.dut.kp, kp)
            ctx.set(self.dut.ki, ki)
            ctx.set(self.dut.sps, sps_reg)
            gap = 9
            for (r, i) in x:
                ctx.set(self.dut.i_in, r)
                ctx.set(self.dut.q_in, i)
                ctx.set(self.dut.in_valid, 1)
                await ctx.tick()
                ctx.set(self.dut.in_valid, 0)
                await ctx.tick().repeat(gap + random.randint(0, 3))
            await ctx.tick().repeat(200)
            done.append(True)

        async def collect(ctx):
            async for clk, rst, v, r, i in ctx.tick().sample(
                    self.dut.out_valid, self.dut.i_out, self.dut.q_out):
                if v:
                    got.append((r, i))
                if done:
                    break

        self.simulate([drive, collect])
        n = min(len(got), len(expected))
        sps_eff = M.sps_effective(sps_reg) / (1 << M.T_FRAC)
        self.assertGreater(n, len(x) / sps_eff - 20)
        mism = [k for k in range(n) if got[k] != expected[k]]
        self.assertEqual(mism[:5], [], f'{len(mism)} of {n} symbols differ')


class TestSymFrontIP(unittest.TestCase):
    """The IP core: AXI-Lite registers, clock domain crossings and bypass."""

    def test_ip(self):
        dut = SymFrontIP()
        x = synthetic(1500)
        step = M.nco_step(0.0125, 1.0)
        kp, ki = M.loop_gains(0.02)
        expected = M.SymFrontModel(step, kp, ki).process(x)
        got, bypass = [], []
        state = {'enabled': False, 'done': False}
        axi = dut.axi4lite.axi

        async def write(ctx, addr, data):
            ctx.set(axi.awaddr, addr)
            ctx.set(axi.awvalid, 1)
            ctx.set(axi.wdata, data)
            ctx.set(axi.wstrb, 0xf)
            ctx.set(axi.wvalid, 1)
            ctx.set(axi.bready, 1)
            aw = w = False
            while not (aw and w):
                await ctx.tick('s_axi_lite')
                aw = aw or ctx.get(axi.awready)
                w = w or ctx.get(axi.wready)
                if aw:
                    ctx.set(axi.awvalid, 0)
                if w:
                    ctx.set(axi.wvalid, 0)
            ctx.set(axi.awvalid, 0)
            ctx.set(axi.wvalid, 0)
            while not ctx.get(axi.bvalid):
                await ctx.tick('s_axi_lite')
            await ctx.tick('s_axi_lite')

        async def cpu(ctx):
            await ctx.tick('s_axi_lite').repeat(20)
            await write(ctx, 0x04, step)
            await write(ctx, 0x08, kp)
            await write(ctx, 0x0c, ki)
            await ctx.tick('s_axi_lite').repeat(200)
            state['enabling'] = True
            await ctx.tick('s_axi_lite').repeat(200)
            await write(ctx, 0x00, 1)
            await ctx.tick('s_axi_lite').repeat(50)
            state['enabled'] = True

        async def samples(ctx):
            # bypass first: what goes in comes out
            k = 0
            while not state.get('enabling'):
                ctx.set(dut.re_in, k)
                ctx.set(dut.im_in, -k)
                ctx.set(dut.strobe_in, 1)
                await ctx.tick('iq')
                if ctx.get(dut.strobe_out) and not ctx.get(dut.active):
                    bypass.append((ctx.get(dut.re_out), ctx.get(dut.im_out), k))
                ctx.set(dut.strobe_in, 0)
                await ctx.tick('iq')
                k += 1
            while not state['enabled']:
                await ctx.tick('iq')
            for (r, i) in x:
                ctx.set(dut.re_in, r)
                ctx.set(dut.im_in, i)
                ctx.set(dut.strobe_in, 1)
                await ctx.tick('iq')
                ctx.set(dut.strobe_in, 0)
                await ctx.tick('iq')
            await ctx.tick('iq').repeat(100)
            state['done'] = True

        async def collect(ctx):
            async for clk, rst, active, v, r, i in ctx.tick('iq').sample(
                    dut.active, dut.strobe_out, dut.re_out, dut.im_out):
                if active and v:
                    got.append((r, i))
                if state['done']:
                    break

        sim = Simulator(dut)
        sim.add_clock(10e-9, domain='s_axi_lite')
        sim.add_clock(8e-9, domain='proc')
        sim.add_clock(50e-9, domain='iq')
        sim.add_testbench(cpu)
        sim.add_testbench(samples)
        sim.add_testbench(collect)
        sim.run()
        self.assertGreater(len(bypass), 10)
        self.assertTrue(all(r == k and i == -k for r, i, k in bypass))
        n = min(len(got), len(expected))
        self.assertGreater(n, len(x) // 2 - 20)
        self.assertEqual(got[:n], expected[:n])


if __name__ == '__main__':
    unittest.main()
