# DDC I/Q alignment test (tone through the DDC)

Hardware test for the DDC clock-domain crossing in `../../common/maiafirtoiq.tcl`: I and Q used to
cross from the maia_sdr clock (62.5 MHz) into the ADC clock domain in two independent async FIFOs
(`interclk_i`, `interclk_q`), and only `interclk_i`'s `tvalid` was used.

`tonetest.py` talks to a running tezuka_fw image over SSH (root/analog) and HTTP:

1. Sets the AD9363 BIST tone to mode 2 (injected into RX; mode 1 is TX) at `fs/32`, 6 dB below full
   scale. At 0 dB the DDC output clips at the signal peaks, which would hide the effect.
2. Tunes the DDC 100 kHz below the tone and switches routing on (maia-httpd
   `PATCH /api/ddc/config`), so the DDC output is a single tone at +100 kHz.
3. Captures CS16 (`voltage0 voltage1`) on the board, 1 s per capture.
4. Predicts every sample from its 8 neighbours on each side (least-squares interpolator over the
   capture) and flags outliers at 10 sigma of the residual. An outlier where only Q is off and Q
   equals its predecessor is a `q_lag` (Q one sample stale); the other classes are `q_lead`, `i_lag`,
   `i_lead`, `dropout` and `other`. The 2 `events` per capture are the interpolator's edge samples
   and are not classified.

`q_slip_detectable_fraction` is the fraction of samples where Q changes by more than the threshold
from one sample to the next, so that a one-sample slip there would be visible (about 93 % here).
A capture only counts if that fraction is above 0.5 and the tone is at 100 kHz +-1 kHz; others are
listed in `invalid_captures`. (The first Pluto run at 61.44 MS/s, started 15 s after boot, lost the
tone after 11 captures, presumably when the boot scripts reconfigured the AD9363; it was repeated. All
captures in the results below pass this check, including the runs made before it was added.)

    FS=61440000 ./tonetest.py <label> <host> 30      # -> results/<label>-tone.json
    ./tonetest.py --selftest <capture.npy>          # plant Q slips in a saved capture

`--selftest` on a 61.44 MS/s capture from the fixed bitstream: 200 planted Q lags and 200 Q leads,
of which 188 and 187 fall where Q changes enough to be visible; all 188 and 187 are found and
classified correctly, with no other events.

## Results (2026-10-11)

All images are tezuka_fw v0.3.23 (2dde77d) built locally, with only `tezuka.xsa` replaced.
"bf83f60" is the build with the F1/F4 fix (#14), whose DDC crossing is unchanged from the shipped
design; "this branch" is ac9b3c7 (the DDC crossing fix only); "this branch + #14" is both merged
(da26cdf). DDC decimation 20.

| Board | Bitstream | ADC rate | DDC samples | Q one sample late | Other events | Tone |
|---|---|---|---|---|---|---|
| Pluto+ | bf83f60 | 30.72 MS/s | 92.16 M | 0 | 0 | +99.99 kHz |
| Pluto+ | bf83f60 | 61.44 MS/s | 92.16 M | **237977 (0.26 %)** | 0 | +99.98 kHz |
| Pluto | bf83f60 | 61.44 MS/s | 92.16 M | **276941 (0.30 %)** | 0 | +99.98 kHz |
| Pluto+ | this branch | 30.72 MS/s | 46.08 M | 0 | 0 | +99.99 kHz |
| Pluto+ | this branch | 61.44 MS/s | 92.16 M | 0 | 0 | +99.97 kHz |
| Pluto | this branch | 30.72 MS/s | 46.08 M | 0 | 0 | +99.99 kHz |
| Pluto | this branch | 61.44 MS/s | 92.16 M | 0 | 0 | +99.98 kHz |
| Pluto+ | this branch + #14 | 30.72 MS/s | 46.08 M | 0 | 0 | +99.99 kHz |
| Pluto+ | this branch + #14 | 61.44 MS/s | 92.16 M | 0 | 0 | +99.98 kHz |
| Pluto | this branch + #14 | 30.72 MS/s | 46.08 M | 0 | 0 | +99.99 kHz |
| Pluto | this branch + #14 | 61.44 MS/s | 92.16 M | 0 | 0 | +99.98 kHz |

All misalignments on the old crossing are `q_lag`: Q stale by exactly one sample, I correct. There
were no `q_lead`, `i_*` or dropout events. They only appear at 61.44 MS/s, where the ADC-side clock
(61.44 MHz) is within about 1 MHz of the 62.5 MHz write clock, so both FIFOs often see a new write
pointer close to a read edge and their synchronisers resolve it differently.

The tone at +100 kHz confirms that I and Q are not swapped by the new `{Q, I}` packing.

Raw data: `results/*-tone.json` (per-capture counts and the first 50 event positions).

## Also seen: DDC overdrive at full scale

With the BIST tone at 0 dB, the DDC output has ~200 LSB errors on one component at the signal peaks
on both crossings (the input is full scale). At 6 dB and below the output is clean. This is in the
DDC itself, not in the crossing, and is not changed here.
