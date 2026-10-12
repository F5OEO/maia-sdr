#
# Copyright (C) 2026 Mario Behn <mario.behn@gmail.com>
#
# This file is part of maia-sdr
#
# SPDX-License-Identifier: MIT
#

from amaranth import *


class RoundSaturate(Elaboratable):
    """Shift right with rounding and saturation

    Computes ``x / 2**shift`` rounded to the nearest integer, with ties
    rounded to even, and saturates the result to a signed ``out_width``
    integer. Unlike a plain arithmetic shift, which rounds towards minus
    infinity and so adds a DC bias of about -0.5 LSB, this has no bias.
    The logic is combinational.

    Parameters
    ----------
    in_width : int
        Width of the input.
    shift : int
        Number of LSBs to drop. Must be at least 1.
    out_width : int
        Width of the output.

    Attributes
    ----------
    x : Signal(signed(in_width)), in
        Input.
    y : Signal(signed(out_width)), out
        Rounded and saturated output.
    """
    def __init__(self, in_width, shift, out_width):
        if shift < 1:
            raise ValueError('shift must be at least 1')
        self.in_width = in_width
        self.shift = shift
        self.out_width = out_width

        self.x = Signal(signed(in_width))
        self.y = Signal(signed(out_width))

    def elaborate(self, platform):
        m = Module()
        # Adding 2**(shift-1) - 1 plus the LSB that is kept rounds ties to
        # even. The sum has one more bit than the input, so it cannot wrap.
        half = 2**(self.shift - 1) - 1
        rounded = Signal(signed(self.in_width + 1))
        m.d.comb += rounded.eq(self.x + half + self.x[self.shift])
        shifted = Signal(signed(self.in_width + 1 - self.shift))
        m.d.comb += shifted.eq(rounded >> self.shift)
        max_out = 2**(self.out_width - 1) - 1
        min_out = -2**(self.out_width - 1)
        with m.If(shifted > max_out):
            m.d.comb += self.y.eq(max_out)
        with m.Elif(shifted < min_out):
            m.d.comb += self.y.eq(min_out)
        with m.Else():
            m.d.comb += self.y.eq(shifted)
        return m
