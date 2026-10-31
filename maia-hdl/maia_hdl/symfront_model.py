#
# Copyright (C) 2026 Yves Petit F4HSL
#
# SPDX-License-Identifier: MIT
#
"""Bit-exact reference model of the DVB-S2 symbol front end (SymFront).

The FPGA front end takes the AD936x samples that the radio's own RRC FIR has
already matched-filtered and decimated to about 2 samples per symbol, and
outputs one timing-recovered symbol per symbol at unit mean power. It moves
the most expensive part of zynqrx (mixer + symbol timer, the `--prefiltered`
path of dvbs_front.cpp / dvbs_dsp.cpp) out of the Cortex-A9.

Signal path (all integer arithmetic, mirrored by symfront.py):

1. DC removal: acc += x - (acc >> DC_SHIFT); x -= acc >> DC_SHIFT.
2. NCO mixer: 32-bit phase accumulator, 1024-entry cos/sin table (Q15),
   complex product rounded back to 16 bits.
3. Interpolator: 8-tap Kaiser-free windowed sinc (raised cosine window, as
   zynqrx's SymbolTimer with halfSpanSymbols = 2), 512 fractional phases,
   coefficients Q14. Two outputs per symbol: y at the instant and m half a
   symbol (one sample) earlier, with the same phase.
4. Gardner timing error e = Re{m * conj(y - y_prev)}, normalised by the
   output power, clamped to +-2, PI loop filter, timing NCO
   t += 2 * (1 - corr) (in samples, 24 fractional bits). As in zynqrx the
   correction from a symbol's error is used for the next-but-one instant.
5. AGC: power P averaged over 4096 symbols (faster at start); y is scaled
   by 1/sqrt(P) through a mantissa table, output Q9 (unit power = 512)
   clamped to 12 bits.

Loop gains are registers: kp and ki with 24 fractional bits (the PI filter
of zynqrx's SymbolTimer::setLoop, see loop_gains()).
"""

import math

DC_SHIFT = 17
NCO_BITS = 32
LUT_BITS = 10
COEF_FRAC = 14
PHASES = 512
TAPS = 8
T_FRAC = 24           # timing instant: samples with 24 fractional bits
E_FRAC = 16           # timing error: 1.0 = 2**16
CORR_FRAC = 40        # loop correction and integrator
K_FRAC = 24           # kp, ki
MANT_BITS = 6         # mantissa bits of the power for the 1/P and 1/sqrt(P) tables
OUT_FRAC = 9          # output symbols: unit power = 2**9, clamped to 12 bits (room for 32APSK peaks, fits the cs8 path)
OUT_BITS = 12


def nco_table():
    n = 1 << LUT_BITS
    cos = [round(32767 * math.cos(2 * math.pi * i / n)) for i in range(n)]
    sin = [round(32767 * math.sin(2 * math.pi * i / n)) for i in range(n)]
    return cos, sin


def interp_bank():
    """bank[p][i]: tap i for fractional delay p / PHASES (zynqrx SymbolTimer::design, prefiltered)."""
    m = TAPS // 2
    bank = []
    for p in range(PHASES):
        row = []
        for i in range(TAPS):
            d = p / PHASES + (m - 1 - i)
            s = 1.0 if abs(d) < 1e-9 else math.sin(math.pi * d) / (math.pi * d)
            w = 0.5 * (1.0 + math.cos(math.pi * d / m))
            row.append(round(s * w * (1 << COEF_FRAC)))
        bank.append(row)
    return bank


def inv_table():
    """1 / mantissa, mantissa = 1 + k / 2**MANT_BITS (rounded to the middle of the bin), Q15."""
    n = 1 << MANT_BITS
    return [round((1 << 15) / (1 + (k + 0.5) / n)) for k in range(n)]


def isqrt_table():
    """1 / sqrt(mantissa) for even exponents (first half) and 1 / sqrt(2 * mantissa) for odd ones, Q15."""
    n = 1 << MANT_BITS
    even = [round((1 << 15) / math.sqrt(1 + (k + 0.5) / n)) for k in range(n)]
    odd = [round((1 << 15) / math.sqrt(2 * (1 + (k + 0.5) / n))) for k in range(n)]
    return even + odd


def loop_gains(bnt, zeta=0.707, roll_off=0.35):
    """kp, ki registers (K_FRAC fractional bits) for a loop noise bandwidth bnt (x symbol period)."""
    kd = max(3.1 * roll_off, 0.15)
    th = bnt / (zeta + 1.0 / (4.0 * zeta))
    d = 1.0 + 2.0 * zeta * th + th * th
    kp = 4.0 * zeta * th / d / kd
    ki = 4.0 * th * th / d / kd
    return round(kp * (1 << K_FRAC)), round(ki * (1 << K_FRAC))


def nco_step(freq_hz, fs_hz):
    """Phase increment that moves a carrier at freq_hz to 0 Hz."""
    return round(-freq_hz / fs_hz * (1 << NCO_BITS)) & ((1 << NCO_BITS) - 1)


def _rshift_round(v, s):
    return (v + (1 << (s - 1))) >> s if s > 0 else v


def _norm(p):
    """p > 0 -> (exponent e, mantissa index k) with p ~ (1 + k / 2**MANT_BITS) * 2**e."""
    e = p.bit_length() - 1
    k = ((p << MANT_BITS) >> e) & ((1 << MANT_BITS) - 1)
    return e, k


def _clamp(v, lo, hi):
    return lo if v < lo else hi if v > hi else v


class SymFrontModel:
    def __init__(self, nco_step_word=0, kp=None, ki=None):
        self.cos, self.sin = nco_table()
        self.bank = interp_bank()
        self.inv = inv_table()
        self.isq = isqrt_table()
        self.step = nco_step_word
        if kp is None:
            kp, ki = loop_gains(0.02)
        self.kp, self.ki = kp, ki
        self.reset()

    def reset(self):
        self.dc_re = self.dc_im = 0
        self.phase = 0
        self.hist = []          # mixed samples, absolute index = self.base + position
        self.base = 0
        self.n = -1             # index of the newest sample
        self.t = (TAPS // 2 + 1) << T_FRAC   # first instant: enough history for the m window
        self.integ = 0
        self.corr = 0
        self.corr_prev = 0
        self.power = 0
        self.count = 0
        self.prev = None
        self.err = []

    def set_gains(self, kp, ki):
        self.kp, self.ki = kp, ki

    def _mix(self, xr, xi):
        self.dc_re += xr - (self.dc_re >> DC_SHIFT)
        self.dc_im += xi - (self.dc_im >> DC_SHIFT)
        xr -= self.dc_re >> DC_SHIFT
        xi -= self.dc_im >> DC_SHIFT
        idx = self.phase >> (NCO_BITS - LUT_BITS)
        c, s = self.cos[idx], self.sin[idx]
        self.phase = (self.phase + self.step) & ((1 << NCO_BITS) - 1)
        yr = _rshift_round(xr * c - xi * s, 15)
        yi = _rshift_round(xr * s + xi * c, 15)
        return _clamp(yr, -32768, 32767), _clamp(yi, -32768, 32767)

    def _symbol(self, out):
        ti = self.t >> T_FRAC
        p = _rshift_round(self.t & ((1 << T_FRAC) - 1), T_FRAC - 9)   # 9 = log2(PHASES)
        if p >= PHASES:
            p = 0
            ti += 1
        h = self.bank[p]
        s0 = ti - (TAPS // 2) + 1 - self.base
        win = self.hist[s0 - 1:s0 + TAPS]       # x[s0-1 .. s0+TAPS-1]
        yr = yi = mr = mi = 0
        for j in range(TAPS):
            hr = h[j]
            yr += hr * win[j + 1][0]
            yi += hr * win[j + 1][1]
            mr += hr * win[j][0]
            mi += hr * win[j][1]
        yr = _clamp(_rshift_round(yr, COEF_FRAC), -32768, 32767)
        yi = _clamp(_rshift_round(yi, COEF_FRAC), -32768, 32767)
        mr = _clamp(_rshift_round(mr, COEF_FRAC), -32768, 32767)
        mi = _clamp(_rshift_round(mi, COEF_FRAC), -32768, 32767)
        # next instant from the correction known so far (the one of the previous symbol)
        self.t += (2 << T_FRAC) - (self.corr_prev >> (CORR_FRAC - T_FRAC - 1))
        # power and AGC
        pw = yr * yr + yi * yi
        sh = 4 if self.count < 64 else 8 if self.count < 1024 else 12
        if self.count == 0:
            self.power = pw
        else:
            self.power += (pw - self.power) >> sh
        self.power = max(self.power, 1)
        e_exp, k = _norm(self.power)
        # Gardner error, normalised by the power: e = Re{m (y - y_prev)*} / P in E_FRAC
        if self.prev is not None:
            raw = mr * (yr - self.prev[0]) + mi * (yi - self.prev[1])
            e = raw * self.inv[k]                      # / mantissa, Q15
            sh2 = max(e_exp + 15 - E_FRAC, 0)      # a power below 2 (silence) is taken as 2
            e = e >> sh2
            e = _clamp(e, -(2 << E_FRAC), 2 << E_FRAC)
            self.integ += self.ki * e
            self.corr_prev = self.kp * e + self.integ
            self.err.append(e)
        self.prev = (yr, yi)
        # output at unit power = 2**OUT_FRAC
        g = self.isq[k + ((e_exp & 1) << MANT_BITS)]
        osh = 15 - OUT_FRAC + (e_exp >> 1)
        lim = 1 << (OUT_BITS - 1)
        orr = _clamp(_rshift_round(yr * g, osh), -lim, lim - 1)
        oi = _clamp(_rshift_round(yi * g, osh), -lim, lim - 1)
        out.append((orr, oi))
        self.count += 1

    def process(self, samples):
        """samples: iterable of (I, Q) integers (12-bit range). Returns the list of output symbols (I, Q) Q9."""
        out = []
        for xr, xi in samples:
            self.hist.append(self._mix(xr, xi))
            self.n += 1
            while (self.t >> T_FRAC) + TAPS // 2 + 1 <= self.n:
                self._symbol(out)
            drop = (self.t >> T_FRAC) - TAPS - self.base
            if drop > 4096:
                del self.hist[:drop]
                self.base += drop
        return out
