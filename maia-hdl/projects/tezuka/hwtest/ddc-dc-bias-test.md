# DC bias of the DDC output to IIO

`maia_sdr.py` narrowed the 16-bit DDC output to the 12 bits of the IIO channels (`S12/16`) with
`>> 4`. An arithmetic shift rounds towards minus infinity, so I and Q carried a DC offset of
-15/32 = -0.47 LSB. `RoundSaturate` now rounds to nearest (ties to even, no bias) and clamps to
[-2048, 2047].

`dcbias.py <label> <host> [captures]` injects the AD9363 BIST tone (mode 2) at fs/32, tunes the DDC
100 kHz below it with routing on, and averages I and Q of the DDC output in CS16 over 5 captures of
1 s. A pure tone averages to essentially zero, so what remains is the bias of the 16-to-12-bit step.

Pluto+, 30.72 MS/s, DDC output 1.536 MS/s:

| BIST level | Amplitude | Mean I / Q, `>> 4` | Mean I / Q, this change |
|---|---|---|---|
| 6 dB | 414 | -0.4706 / -0.4706 | 0.0000 / 0.0001 |
| 12 dB | 207 | -0.4707 / -0.4707 | 0.0001 / 0.0001 |
| 18 dB | 103 | -0.4684 / -0.4684 | 0.0001 / 0.0001 |

The spread between captures is at most 0.0002 LSB. Even with a 0 dB (full-scale) BIST tone the DDC
output peaks at +-831, so the saturation never engages in practice. It only guards the step for
inputs the DDC does not produce today.

Raw data: `results/plutoplus-before-dcbias.json`, `results/plutoplus-after-dcbias.json`.
