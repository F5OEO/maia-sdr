#
# Copyright (C) 2026 Yves Petit F4HSL
#
# SPDX-License-Identifier: MIT
#
"""DVB-S2 symbol front end (SymFront).

Takes the AD936x samples after the radio's RRC FIR (about 2 samples per
symbol) and outputs one timing-recovered symbol per symbol at unit mean
power, so that zynqrx can skip its mixer and symbol timer (``--symbols``).

Bit-exact with :mod:`maia_hdl.symfront_model`, which documents the
arithmetic. One processing clock (``sync``); the input samples come with a
``in_valid`` strobe and must be at least 8 clock cycles apart on average,
and a symbol takes about 22 cycles: at 100 MHz this covers the whole range
of the AD936x RRC path (up to 7.68 Msym/s needs 154 MHz; 5 Msym/s fits
100 MHz).
"""

from amaranth import *
from amaranth.lib.memory import Memory
from amaranth.lib.fifo import AsyncFIFO
from amaranth.lib.cdc import FFSynchronizer
import amaranth.cli

from . import symfront_model as M
from .axi4_lite import Axi4LiteRegisterBridge
from .cdc import RegisterCDC
from .register import Access, Field, Registers, Register


def _round_shift(v, s, width):
    """Rounded arithmetic right shift by a constant."""
    return ((v + (1 << (s - 1))) >> s)[:width].as_signed() if s > 0 else v


def _clamp(v, bits):
    lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    return Mux(v > hi, hi, Mux(v < lo, lo, v))


class SymFront(Elaboratable):
    """Mixer + interpolator + Gardner loop + AGC.

    Attributes
    ----------
    i_in, q_in : Signal(signed(16)), in
        Samples (12-bit range).
    in_valid : Signal(), in
    nco_step : Signal(32), in
        Phase increment, :func:`symfront_model.nco_step`.
    kp, ki : Signal(24), in
        Loop gains, :func:`symfront_model.loop_gains`.
    i_out, q_out : Signal(signed(16)), out
        Symbols, unit power = 512, 12-bit range.
    out_valid : Signal(), out
        One-cycle strobe per symbol.
    power : Signal(34), out
        Averaged power of the interpolator output (for the AGC readout).
    """
    RING = 32

    def __init__(self):
        self.i_in = Signal(signed(16))
        self.q_in = Signal(signed(16))
        self.in_valid = Signal()
        self.nco_step = Signal(32)
        self.kp = Signal(24)
        self.ki = Signal(24)
        self.i_out = Signal(signed(16))
        self.q_out = Signal(signed(16))
        self.out_valid = Signal()
        self.power = Signal(34)

    def ports(self):
        return [self.i_in, self.q_in, self.in_valid, self.nco_step,
                self.kp, self.ki, self.i_out, self.q_out, self.out_valid,
                self.power]

    def elaborate(self, platform):
        m = Module()
        cos_t, sin_t = M.nco_table()
        bank = M.interp_bank()
        inv_t = M.inv_table()
        isq_t = M.isqrt_table()

        # ---------------------------------------------------------------- mixer
        dc_re = Signal(signed(16 + M.DC_SHIFT + 2))
        dc_im = Signal(signed(16 + M.DC_SHIFT + 2))
        phase = Signal(32)
        m.submodules.lut_cos = lut_cos = Memory(
            shape=signed(16), depth=1 << M.LUT_BITS, init=cos_t)
        m.submodules.lut_sin = lut_sin = Memory(
            shape=signed(16), depth=1 << M.LUT_BITS, init=sin_t)
        rc = lut_cos.read_port()
        rs = lut_sin.read_port()
        m.d.comb += [rc.addr.eq(phase[32 - M.LUT_BITS:]),
                     rs.addr.eq(phase[32 - M.LUT_BITS:])]

        new_dc_re = Signal.like(dc_re)
        new_dc_im = Signal.like(dc_im)
        m.d.comb += [
            new_dc_re.eq(dc_re + self.i_in - (dc_re >> M.DC_SHIFT)),
            new_dc_im.eq(dc_im + self.q_in - (dc_im >> M.DC_SHIFT)),
        ]
        xd_re = Signal(signed(18))
        xd_im = Signal(signed(18))
        v1 = Signal()
        with m.If(self.in_valid):
            m.d.sync += [
                dc_re.eq(new_dc_re), dc_im.eq(new_dc_im),
                xd_re.eq(self.i_in - (new_dc_re >> M.DC_SHIFT)),
                xd_im.eq(self.q_in - (new_dc_im >> M.DC_SHIFT)),
                phase.eq(phase + self.nco_step),
            ]
        m.d.sync += v1.eq(self.in_valid)
        # stage 2: products (the table output is valid one cycle after the address)
        p_rr = Signal(signed(34))
        p_ii = Signal(signed(34))
        p_ri = Signal(signed(34))
        p_ir = Signal(signed(34))
        v2 = Signal()
        m.d.sync += [
            p_rr.eq(xd_re * rc.data), p_ii.eq(xd_im * rs.data),
            p_ri.eq(xd_re * rs.data), p_ir.eq(xd_im * rc.data),
            v2.eq(v1),
        ]
        # stage 3: sum, round, clamp, write into the ring
        mix_re = _clamp(_round_shift(p_rr - p_ii, 15, 21), 16)
        mix_im = _clamp(_round_shift(p_ri + p_ir, 15, 21), 16)
        ring_re = Array(Signal(signed(16), name=f'ring_re{i}') for i in range(self.RING))
        ring_im = Array(Signal(signed(16), name=f'ring_im{i}') for i in range(self.RING))
        n_cnt = Signal(16)          # samples written
        with m.If(v2):
            m.d.sync += [
                ring_re[n_cnt[:5]].eq(mix_re),
                ring_im[n_cnt[:5]].eq(mix_im),
                n_cnt.eq(n_cnt + 1),
            ]

        # ---------------------------------------------------------------- symbol engine
        TF = M.T_FRAC
        t = Signal(16 + TF, init=(M.TAPS // 2 + 1) << TF)
        t_int = t[TF:]
        corr = Signal(signed(58))
        integ = Signal(signed(58))
        p_idx = Signal(10)
        ti = Signal(16)
        j = Signal(4)
        m.submodules.bank = bank_mem = Memory(
            shape=signed(16), depth=M.PHASES * M.TAPS,
            init=[c for row in bank for c in row])
        rb = bank_mem.read_port()
        acc_yr = Signal(signed(36))
        acc_yi = Signal(signed(36))
        acc_mr = Signal(signed(36))
        acc_mi = Signal(signed(36))
        sy_re = Signal(signed(16))
        sy_im = Signal(signed(16))
        sm_re = Signal(signed(16))
        sm_im = Signal(signed(16))
        mac_en = Signal()
        yr = Signal(signed(16))
        yi = Signal(signed(16))
        mr = Signal(signed(16))
        mi = Signal(signed(16))
        pr = Signal(signed(16))
        pi = Signal(signed(16))
        have_prev = Signal()
        count = Signal(11)          # saturates at 1024
        pw = Signal(33)
        d_r = Signal(signed(17))
        d_i = Signal(signed(17))
        raw = Signal(signed(35))
        pwr = Signal(34)
        e_exp = Signal(6)
        k = Signal(M.MANT_BITS)
        inv = Signal(16)
        g = Signal(16)
        e_full = Signal(signed(51))
        e = Signal(signed(19))
        kp_e = Signal(signed(45))
        ki_e = Signal(signed(45))
        ym_r = Signal(signed(32))
        ym_i = Signal(signed(32))

        newest_minus = Signal(signed(16))
        m.d.comb += newest_minus.eq(n_cnt - 1 - t_int - (M.TAPS // 2 + 1))

        s0 = Signal(16)
        m.d.comb += [
            s0.eq(ti - (M.TAPS // 2) + 1),
            rb.addr.eq(Cat(j[:3], p_idx[:9])),
        ]
        # samples of tap j: y window x[s0 + j], m window x[s0 - 1 + j]
        m.d.sync += mac_en.eq(0)
        with m.If(mac_en):
            m.d.sync += [
                acc_yr.eq(acc_yr + rb.data * sy_re),
                acc_yi.eq(acc_yi + rb.data * sy_im),
                acc_mr.eq(acc_mr + rb.data * sm_re),
                acc_mi.eq(acc_mi + rb.data * sm_im),
            ]

        # exponent of the power: position of its leading one
        lead = Signal(6)
        for b in range(34):
            with m.If(pwr[b]):
                m.d.comb += lead.eq(b)
        norm = Signal(34)
        shl = Signal(6)
        m.d.comb += [shl.eq(33 - lead), norm.eq(pwr << shl)]

        inv_arr = Array(Const(v, 16) for v in inv_t)
        isq_arr = Array(Const(v, 16) for v in isq_t)
        sh2 = Signal(6)
        m.d.comb += sh2.eq(Mux(e_exp > 0, e_exp - 1, 0))
        osh = Signal(6)
        m.d.comb += osh.eq(15 - M.OUT_FRAC + (e_exp >> 1))
        e_shifted = Signal(signed(51))
        m.d.comb += e_shifted.eq(e_full >> sh2)
        emax = 2 << M.E_FRAC
        osh1 = Signal(6)
        m.d.comb += osh1.eq(osh - 1)
        o_r = Signal(signed(33))
        o_i = Signal(signed(33))
        m.d.comb += [
            o_r.eq((ym_r + (Const(1, 33) << osh1)) >> osh),
            o_i.eq((ym_i + (Const(1, 33) << osh1)) >> osh),
        ]

        m.d.sync += self.out_valid.eq(0)
        with m.FSM():
            with m.State('IDLE'):
                with m.If(newest_minus >= 0):
                    # fractional phase rounded to 9 bits; a carry moves to the next sample
                    p_full = (t[:TF] + (1 << (TF - 10))) >> (TF - 9)
                    m.d.sync += [
                        p_idx.eq(p_full[:9]),
                        ti.eq(t_int + p_full[9]),
                        # next instant, from the correction of the previous symbol
                        t.eq(t + (2 << TF) - (corr >> (M.CORR_FRAC - TF - 1))),
                        j.eq(0),
                        acc_yr.eq(0), acc_yi.eq(0), acc_mr.eq(0), acc_mi.eq(0),
                    ]
                    m.next = 'MAC'
            with m.State('MAC'):
                # address j to the coefficient table now, its samples one cycle later with the data
                m.d.sync += [
                    sy_re.eq(ring_re[(s0 + j)[:5]]),
                    sy_im.eq(ring_im[(s0 + j)[:5]]),
                    sm_re.eq(ring_re[(s0 + j - 1)[:5]]),
                    sm_im.eq(ring_im[(s0 + j - 1)[:5]]),
                    mac_en.eq(1),
                    j.eq(j + 1),
                ]
                with m.If(j == M.TAPS - 1):
                    m.next = 'MACWAIT'
            with m.State('MACWAIT'):
                m.next = 'ROUND'
            with m.State('ROUND'):
                m.d.sync += [
                    yr.eq(_clamp(_round_shift(acc_yr, M.COEF_FRAC, 23), 16)),
                    yi.eq(_clamp(_round_shift(acc_yi, M.COEF_FRAC, 23), 16)),
                    mr.eq(_clamp(_round_shift(acc_mr, M.COEF_FRAC, 23), 16)),
                    mi.eq(_clamp(_round_shift(acc_mi, M.COEF_FRAC, 23), 16)),
                ]
                m.next = 'PW'
            with m.State('PW'):
                m.d.sync += [
                    pw.eq(yr * yr + yi * yi),
                    d_r.eq(yr - pr),
                    d_i.eq(yi - pi),
                ]
                m.next = 'POW'
            with m.State('POW'):
                diff = Signal(signed(35))
                m.d.comb += diff.eq(pw - pwr)
                with m.If(count == 0):
                    m.d.sync += pwr.eq(pw)
                with m.Elif(count < 64):
                    m.d.sync += pwr.eq(pwr + (diff >> 4))
                with m.Elif(count < 1024):
                    m.d.sync += pwr.eq(pwr + (diff >> 8))
                with m.Else():
                    m.d.sync += pwr.eq(pwr + (diff >> 12))
                m.d.sync += raw.eq(mr * d_r + mi * d_i)
                m.next = 'NORM'
            with m.State('NORM'):
                # max(power, 1)
                with m.If(pwr == 0):
                    m.d.sync += pwr.eq(1)
                m.next = 'NORM2'
            with m.State('NORM2'):
                kk = norm[33 - M.MANT_BITS:33]
                m.d.sync += [
                    e_exp.eq(lead),
                    k.eq(kk),
                    inv.eq(inv_arr[kk]),
                    g.eq(isq_arr[Cat(kk, lead[0])]),
                ]
                m.next = 'EMUL'
            with m.State('EMUL'):
                m.d.sync += [
                    e_full.eq(raw * inv),
                    ym_r.eq(yr * g),
                    ym_i.eq(yi * g),
                ]
                m.next = 'ESHIFT'
            with m.State('ESHIFT'):
                m.d.sync += e.eq(Mux(e_shifted > emax, emax,
                                     Mux(e_shifted < -emax, -emax, e_shifted)))
                m.d.sync += [
                    self.i_out.eq(_clamp(o_r, M.OUT_BITS)),
                    self.q_out.eq(_clamp(o_i, M.OUT_BITS)),
                    self.out_valid.eq(1),
                ]
                m.next = 'LOOP1'
            with m.State('LOOP1'):
                m.d.sync += [kp_e.eq(self.kp * e), ki_e.eq(self.ki * e)]
                m.next = 'LOOP2'
            with m.State('LOOP2'):
                with m.If(have_prev):
                    m.d.sync += [
                        integ.eq(integ + ki_e),
                        corr.eq(kp_e + integ + ki_e),
                    ]
                m.d.sync += [
                    pr.eq(yr), pi.eq(yi), have_prev.eq(1),
                    count.eq(Mux(count == 1024, count, count + 1)),
                ]
                m.next = 'IDLE'

        m.d.comb += self.power.eq(pwr)
        return m


class SymFrontIP(Elaboratable):
    """SymFront as a Vivado IP core, inserted in the RX sample path.

    It sits between the RX sample source (``mux_decim``) and the cs12/cs8
    packing, like ``iqburst``. Disabled, the samples go straight through
    (``re_out = re_in``, ``strobe_out = strobe_in``). Enabled, the output is
    the symbol stream: one strobe per symbol, unit power = 512.

    Clock domains: ``iq`` (the sample clock of the RX path), ``proc`` (a fast
    processing clock, at least 8 cycles per input sample), ``s_axi_lite``.

    Registers (byte address)

    0x00 control  [0] enable (0 holds the front end in reset and bypasses it)
    0x04 nco_step phase increment of the mixer (symfront_model.nco_step)
    0x08 kp       [23:0] proportional gain of the timing loop
    0x0c ki       [23:0] integral gain of the timing loop
    0x10 power    (R) interpolator output power >> 2 (AGC level)
    0x14 symbols  (R) symbols made since enable
    0x18 status   (R) [0] input FIFO overflow, [1] output FIFO overflow (sticky until disable)
    """
    def __init__(self):
        self.s_axi_lite = ClockDomain('s_axi_lite')
        self.iq = ClockDomain('iq')
        self.proc = ClockDomain('proc')
        self.axi4lite = Axi4LiteRegisterBridge(3, name='s_axi_lite')
        self.registers = Registers(
            'symfront',
            {
                0: Register('control', [Field('enable', Access.RW, 1, 0)]),
                1: Register('nco_step', [Field('nco_step', Access.RW, 32, 0)]),
                2: Register('kp', [Field('kp', Access.RW, 24, 0)]),
                3: Register('ki', [Field('ki', Access.RW, 24, 0)]),
                4: Register('power', [Field('power', Access.R, 32, 0)]),
                5: Register('symbols', [Field('symbols', Access.R, 32, 0)]),
                6: Register('status', [Field('in_overflow', Access.R, 1, 0),
                                       Field('out_overflow', Access.R, 1, 0)]),
            },
            3)
        self.re_in = Signal(signed(16))
        self.im_in = Signal(signed(16))
        self.strobe_in = Signal()
        self.re_out = Signal(signed(16))
        self.im_out = Signal(signed(16))
        self.strobe_out = Signal()
        self.active = Signal()

    def ports(self):
        return (
            self.axi4lite.axi.ports()
            + [self.re_in, self.im_in, self.strobe_in,
               self.re_out, self.im_out, self.strobe_out, self.active,
               self.s_axi_lite.clk, self.s_axi_lite.rst,
               self.iq.clk, self.iq.rst,
               self.proc.clk, self.proc.rst]
        )

    def elaborate(self, platform):
        m = Module()
        m.domains += [self.s_axi_lite, self.iq, self.proc]

        m.submodules.axi4lite = DomainRenamer({'sync': 's_axi_lite'})(
            self.axi4lite)
        m.submodules.reg_cdc = reg_cdc = RegisterCDC(
            's_axi_lite', 'proc', self.registers.aw)
        m.d.comb += [
            reg_cdc.i_ren.eq(self.axi4lite.ren),
            self.axi4lite.rdone.eq(reg_cdc.i_rdone),
            self.axi4lite.wdone.eq(reg_cdc.i_wdone),
            reg_cdc.i_wstrobe.eq(self.axi4lite.wstrobe),
            reg_cdc.i_address.eq(self.axi4lite.address),
            self.axi4lite.rdata.eq(reg_cdc.i_rdata),
            reg_cdc.i_wdata.eq(self.axi4lite.wdata),
            self.registers.ren.eq(reg_cdc.o_ren),
            reg_cdc.o_rdone.eq(self.registers.rdone),
            self.registers.wstrobe.eq(reg_cdc.o_wstrobe),
            reg_cdc.o_wdone.eq(self.registers.wdone),
            self.registers.address.eq(reg_cdc.o_address),
            reg_cdc.o_rdata.eq(self.registers.rdata),
            self.registers.wdata.eq(reg_cdc.o_wdata),
        ]
        m.submodules.registers = DomainRenamer({'sync': 'proc'})(
            self.registers)
        enable = self.registers['control']['enable']

        # enable in the iq domain (quasi-static)
        active_iq = Signal()
        m.submodules.en_sync = FFSynchronizer(enable, active_iq, o_domain='iq')
        m.d.comb += self.active.eq(active_iq)

        # samples iq -> proc
        m.submodules.fifo_in = fifo_in = AsyncFIFO(
            width=32, depth=16, r_domain='proc', w_domain='iq')
        m.d.comb += [
            fifo_in.w_data.eq(Cat(self.re_in, self.im_in)),
            fifo_in.w_en.eq(self.strobe_in & active_iq),
            fifo_in.r_en.eq(1),
        ]
        in_ovf_iq = Signal()
        with m.If(~active_iq):
            m.d.iq += in_ovf_iq.eq(0)
        with m.Elif(self.strobe_in & ~fifo_in.w_rdy):
            m.d.iq += in_ovf_iq.eq(1)

        # the front end, held in reset while disabled
        core = SymFront()
        m.submodules.core = core = DomainRenamer({'sync': 'proc'})(
            ResetInserter(~enable)(core))
        m.d.comb += [
            core.i_in.eq(fifo_in.r_data[:16]),
            core.q_in.eq(fifo_in.r_data[16:]),
            core.in_valid.eq(fifo_in.r_rdy & enable),
            core.nco_step.eq(self.registers['nco_step']['nco_step']),
            core.kp.eq(self.registers['kp']['kp']),
            core.ki.eq(self.registers['ki']['ki']),
            self.registers['power']['power'].eq(core.power[2:]),
        ]
        nsym = Signal(32)
        with m.If(~enable):
            m.d.proc += nsym.eq(0)
        with m.Elif(core.out_valid):
            m.d.proc += nsym.eq(nsym + 1)
        m.d.comb += self.registers['symbols']['symbols'].eq(nsym)

        # symbols proc -> iq
        m.submodules.fifo_out = fifo_out = AsyncFIFO(
            width=32, depth=16, r_domain='iq', w_domain='proc')
        m.d.comb += [
            fifo_out.w_data.eq(Cat(core.i_out, core.q_out)),
            fifo_out.w_en.eq(core.out_valid),
        ]
        out_ovf = Signal()
        with m.If(~enable):
            m.d.proc += out_ovf.eq(0)
        with m.Elif(core.out_valid & ~fifo_out.w_rdy):
            m.d.proc += out_ovf.eq(1)
        in_ovf = Signal()
        m.submodules.ovf_sync = FFSynchronizer(in_ovf_iq, in_ovf, o_domain='proc')
        m.d.comb += [
            self.registers['status']['in_overflow'].eq(in_ovf),
            self.registers['status']['out_overflow'].eq(out_ovf),
        ]

        # one symbol per strobe in the iq domain; bypass when disabled
        sym_re = Signal(signed(16))
        sym_im = Signal(signed(16))
        sym_stb = Signal()
        m.d.comb += fifo_out.r_en.eq(active_iq)
        m.d.iq += [
            sym_stb.eq(fifo_out.r_rdy & active_iq),
            sym_re.eq(fifo_out.r_data[:16]),
            sym_im.eq(fifo_out.r_data[16:]),
        ]
        m.d.comb += [
            self.re_out.eq(Mux(active_iq, sym_re, self.re_in)),
            self.im_out.eq(Mux(active_iq, sym_im, self.im_in)),
            self.strobe_out.eq(Mux(active_iq, sym_stb, self.strobe_in)),
        ]
        return m


if __name__ == '__main__':
    dut = SymFrontIP()
    amaranth.cli.main(dut, ports=dut.ports())
