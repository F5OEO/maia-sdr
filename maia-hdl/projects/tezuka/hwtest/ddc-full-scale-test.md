# DDC with a full-scale input

The DDC mixer rotated each 12-bit input sample and kept a 12-bit result. A rotation keeps the
magnitude of a sample, but one component of the result can be as large as the whole magnitude: up to
2048 for a full-scale complex tone, and up to sqrt(2) * 2048 = 2896 when I and Q are both near full
scale. Anything above 2047 wrapped around to a large negative value, and the decimating FIR spread
each wrap into an error of about 200 LSB in the DDC output. `Mixer` now takes an `out_width`, and the
DDC uses 13 bits from the mixer to the decimator. `Mixer`'s default stays `width`, so the TX modulator
is unchanged.

**Model** (`Mixer.model`, 20000 random full-range 12-bit I/Q, every 7th sample at -2048 - 2048j,
compared with the exact rotation by the same table phases):

| Mixer output | Max error | Samples off by > 3 LSB |
|---|---|---|
| 12 bits | 8192 LSB (wrap) | 4861 (24 %) |
| 13 bits | 1 LSB | 0 |

`test/test_mixer.py::test_mixer_full_scale_no_wrap` checks the 13-bit mixer in simulation against the
model, and the model against the exact rotation.

**Hardware** (Pluto+, 30.72 MS/s, DDC output 1.536 MS/s): `tonetest.py` (same as in #15) injects the
AD9363 BIST tone, tunes the DDC 100 kHz below it, and checks every DDC output sample against a
two-sided predictor; 10 captures of 1 s each.

| BIST level | 12-bit mixer | 13-bit mixer |
|---|---|---|
| 0 dB (full scale) | 246429 error events in 15.36 M samples (one component, about 200 LSB) | 0, noise 0.85 LSB |
| 6 dB | 0 | 0 |

Raw data: `results/plutoplus-{before,after}-mixer13-L{0,6}-tone.json`.
