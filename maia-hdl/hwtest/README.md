# Hardware tests of the raw capture and the I/Q waterfall

These scripts check `raw_capture` (single-shot burst of 64 FFT frames of
complex bins) and `iq_dma` (the continuous `/iq-waterfall`, one complex
frame per integration epoch) on real hardware. Both tap `fft.re_out` /
`fft.im_out`, truncated to 16 bits, so they can be compared with each other
and with the magnitude waterfall.

## Data formats

- `/iq-waterfall`: 16384-byte websocket messages, 4096 bins, one `u32` per
  bin with I in the high 16 bits and Q in the low 16 bits (signed), in
  waterfall bin order (bin 2048 is DC).
- `/raw-capture` (`GET`, after `PATCH /api/raw-capture {"state_change":
  "Start"}`): 1 MiB = 64 frames x 4096 bins of `int16` I, Q. The samples are
  the FFT output in bit-reversed bin order (waterfall bin = bit reversal of
  the index within the frame), and the capture starts at an arbitrary
  position in a frame. `hwlib.py` and `rf_iq_check.py` show how to undo
  both.

## Board requirements

The two DMA masters (`m_axi_spectrometer_raw`, `m_axi_spectrometer_iq`)
must be connected to the PS7 in the Vivado project and the device tree
needs reserved-memory nodes for their buffers (`raw_capture` at
0x1a100000 and `iq_waterfall` at 0x1a200000, see `config.py`).

`projects/pluto/system_bd.tcl` does this for the `maia_iio` builds
(`pluto_iio`, `plutoplus_iio`): the raw master is on HP3 (CPU clock) and
the I/Q master on HP0 (maia_sdr clock, own reset generator), the raw
master is associated with the `s_axi_lite` clock in `package_ip.tcl`, and
`projects/pluto/reset_timing.xdc` waives the recovery/removal checks on the
asynchronous resets of the HP interconnects and of the raw FIFO. The other
projects (`pluto`, `plutoplus`, e200, fishball, libre, ...) still leave the
two masters unconnected.

Vivado 2023.2, `plutoplus_iio` and `pluto_iio`: WNS +0.189 ns, WHS +0.017
ns, no failing endpoints (the two have the same figures).

## Scripts

All need `numpy`, `websockets`, `sshpass` and, for the phase test, the
libiio tools (`iio_readdev`) on the host. The RF tests need a second board
(the transmitter, default 192.168.2.1) and a cable with an attenuator
(40 dB used here) from its TX to RX of the board under test (default
192.168.3.1). Both boards' radio settings are restored at the end.

- `bist_check.py`: AD9361 BIST tone (noise-free). I/Q peak bin equals the
  magnitude peak bin, log spectra correlate, and every value of the raw
  capture appears 64 times as often as in one I/Q frame.
- `rf_iq_check.py --fs <rate>`: CW tones, noise reference and CP-OFDM
  through the cable; magnitude, I/Q and raw capture peaks agree (the peak of
  a single I/Q frame may sit on a neighbouring bin when the tone is near a
  half-bin position), OFDM log spectra of magnitude and I/Q correlate.
- `rf_phase_check.py --fs <rate>`: phase check with CW tones (see the
  docstring): frame-to-frame phase advance against a time-domain frequency
  measurement, bin-to-bin phase against a windowed-FFT model, I/Q waterfall
  against raw capture. The frames of the raw capture are aligned on the bins
  around the peak (not on one bin), the model is fitted with a complex
  amplitude per frame, and only bins at least 20 dB above the noise floor are
  scored (`model_bins`); with the tone near a half-bin position the earlier
  version could print errors of 180 degrees and tens of dB.
- `rf_iq_frame_phase_check.py --fs <rate>`: phase between consecutive I/Q
  waterfall frames (see the docstring and the results section). Changes
  `number_integrations` through the API and restores it.

## Results (Pluto+, 40 dB cable, 2.4 GHz LO, 2026-10-16)

The table was measured with the wiring of an integration branch with the
same HP0/HP3 scheme; the wiring in this PR was then checked on a Pluto+
image built from this branch (tezuka_fw v0.3.23 plus a bitstream from
`plutoplus_iio`, device-tree nodes and maia-httpd from this tree): the BIST
check, `rf_iq_check.py` at 2.5, 10 and 61.44 MS/s and `rf_phase_check.py`
at 10 and 61.44 MS/s all pass, with figures comparable to the table.
`pluto_iio` was then run on the original Pluto (see the next section).

Build-verified in simulation: the Spectrometer cocotb suite (5 pass, 2
opt-in exact tests skipped) and `test/test_dma.py` (3 tests). Everything
below was run on hardware.

BIST tone, 78.125, 156.25 and 312.5 kHz at 2.5 MS/s: I/Q and magnitude
peaks on the same bin (2176, 2304, 2560), log-spectrum correlation
0.9999993 or better, raw multiset match 100%, one distinct raw frame.

Real signal over the cable (original Pluto TX into Pluto+ RX). The tone
offset between the two boards is about -49.5 kHz (20 ppm reference
difference at 2.4 GHz). "Phase - TD" is the frequency from the raw
capture's frame-to-frame phase advance minus the libiio time-domain
frequency; the two board references drift by tens of Hz during a run (up
to 157 Hz at 61.44 MS/s), so this difference is limited by the reference,
not by the phase. The model columns are for the bins within +-3 of the
peak, relative to the peak.

| Rate (MS/s) | Peak bins magnitude / I/Q / raw | Phase - TD (Hz, 3 tones) | Frame phase scatter (rad) | Model phase / amplitude error | OFDM log corr, in/out band mag / I/Q (dB) |
|---|---|---|---|---|---|
| 2.5 | agree, all frames | -12.0, -2.6, 0.0 | 0.005 | <= 1.4 deg / 0.13 dB | 0.99, 34.8 / 29.0 |
| 10 | agree, all frames | -13.0, -4.6, -2.6 | 0.003 | <= 0.7 deg / 0.11 dB | 0.996, 26.8 / 25.6 |
| 20 | agree, all frames | -13.0, -5.9, -3.4 | 0.006 | <= 0.3 deg / 0.11 dB | 0.997, 26.1 / 24.8 |
| 30.72 | agree (one tone half-way between two bins) | -15.2, -4.3, -4.0 | 0.006 | <= 2.3 deg / 0.8 dB (half-bin tone), else <= 1.1 deg / 0.08 dB | 0.998, 26.2 / 25.0 |
| 61.44 | agree, all frames | -21.4, -7.7, -5.9 | 0.004 | <= 0.67 deg / 0.59 dB | 0.998, 25.2 / 24.1 |

The I/Q waterfall and the raw capture neighbour phases agree within about
1 degree next to the peak at every rate (a few bins show up to 10 degrees
on low-amplitude edge bins). The outer bins (more than 3 from the peak)
are quantisation limited and not meaningful for phase. A free-running
noise reference (TX at -89 dB) shows the LO leakage at the DC bin.

## Results (original Pluto, wiring of this PR, 2026-10-16)

Image: tezuka_fw v0.3.23 plus the `pluto_iio` bitstream built from this
branch (timing met, see above), the raw capture and I/Q waterfall
reserved-memory nodes (the Pluto build uses its own copy of the device
tree under `board/tezuka/pluto/kernel-dts`, which has to carry them too)
and maia-httpd from this tree. The link is reversed: Pluto+ TX into
Pluto RX over the same 40 dB cable, 2.4 GHz LO. The tone offset in this
direction was +48.9 kHz at that time and has since measured +49.4 to
+49.9 kHz (the references drift by about a kHz, so a fixed value goes
stale); `rf_iq_check.py` now measures it from a time-domain tone
(`--offset auto`, the default; a number in Hz still works), and `--rx-gain 52` was used for the
`rf_iq_check.py` OFDM test at 2.5 MS/s and for all phase runs.

- BIST check (0.96, 1.92 and 3.84 MHz): I/Q and magnitude peaks equal,
  log-spectrum correlation 0.9999997 or better, raw multiset match 15/15
  and 16/16 twice, one distinct raw frame.
- `rf_iq_check.py`: passes at 10 MS/s (OFDM log corr 0.986), 20 MS/s
  (0.998, in/out band 27.0 / 25.7 dB), 30.72 MS/s (0.998, 26.0 / 24.9 dB)
  and 61.44 MS/s (0.994); peaks of magnitude, I/Q and raw capture agree. At 2.5 MS/s the tones pass with the right offset and the OFDM
  test passes at RX gain 52 (corr 0.9892, in/out band 35.9 dB magnitude /
  29.6 dB I/Q). At the default gain 40 the OFDM correlation is 0.9765
  (below the 0.98 threshold, in/out band 26.7 / 17.7 dB): this link is
  weaker than the Pluto+ RX direction and the I/Q path is quantisation
  limited at low levels. With the Pluto+ RX offset of -49.5 kHz the 2.5
  MS/s tone check fails by one to two bins (610 Hz each); that was the
  offset, not the design.
- `rf_phase_check.py`, 3 tones each:

| Rate (MS/s) | Phase - TD (Hz) | Frame phase scatter (rad) | Model phase / amplitude error | I/Q vs raw phase diff (deg) | TD drift (Hz) |
|---|---|---|---|---|---|
| 2.5 | -5.5, -5.4, -4.1 | 0.006 | <= 2.7 deg / 0.35 dB | 16.2, 3.5, 6.5 | 25 to 40 |
| 10 | -2.2, -1.7, -0.2 | 0.003 to 0.004 | <= 3.2 deg / 0.36 dB | 3.9, 0.5, 0.8 | 5 to 8 |
| 20 | 1.1, -0.4, -0.4 | 0.006 | <= 0.9 deg / 0.28 dB | 0.7, 2.7, 0.8 | 9 to 10 |
| 30.72 | -0.1, 0.8, 0.3 | 0.005 to 0.006 | <= 1.1 deg / 0.23 dB | 3.4, 0.8, 1.0 | 3.5 to 10 |
| 61.44 | 7.3, 7.3, 5.8 | 0.004 | <= 2.8 deg / 0.2 dB | 1.0, 3.9, 0.9 | 55 to 86 |

One tone per rate (the first at 2.5 and 10 MS/s, the second at 61.44)
shows a model error of 2.7 to 3.2 degrees and the first 2.5 MS/s tone a
16 degree I/Q-versus-raw difference; the other tones are within 1
degree. The cause was not investigated (the 2.5 MS/s Pluto+ run had a
similar half-bin tone, but the tone positions of these runs were not
checked against the bin centres). The 20 and 30.72 MS/s tones are all within 1.1 degrees.

## Phase between I/Q waterfall frames (both boards, 2026-10-16)

`rf_iq_frame_phase_check.py`: two tones from one TX buffer, 51 buffer
periods (8.356 bins, not a whole number) apart. A single tone cannot be
used: the frames are 68 to 100 ms apart and the references drift by tens of
Hz. The phase of X1 * conj(X2) at the two peak bins rotates at the
difference frequency as the receiver sees it, which is known: the TX
buffer difference scaled by the sample clock ratio, taken from the carrier
offset (delta, about +-20.4 ppm, measured with a single tone in the time
domain). The prediction per frame is
`2 pi (f1 - f2) (1 + delta) nint 4096 / fs`; a lost frame or a spacing off
by one FFT frame (4096 samples) changes the rotation (by 2.2 rad for the
latter). `number_integrations` is set for about 100 ms between frames (68 ms
at 61.44 MS/s, nint 1023) and restored afterwards. 101 frames (148 at
61.44) per run, 40 dB cable, 2.4 GHz LO, same images as above.

| Board | Rate (MS/s) | nint | Frames | Measured - predicted (rad) | Scatter (rad) | Frames off by > 0.3 rad |
|---|---|---|---|---|---|---|
| Pluto | 2.5 | 61 | 101 | 0.0001 | 0.0009 | 0 |
| Pluto | 10 | 244 | 101 | 0.0004 | 0.0010 | 0 |
| Pluto | 20 | 488 | 101 | 0.0000 | 0.0012 | 0 |
| Pluto | 30.72 | 749 | 101 | -0.0005 | 0.0014 | 0 |
| Pluto | 61.44 | 1023 | 148 | -0.0018 | 0.0020 | 0 |
| Pluto+ | 2.5 | 61 | 101 | 0.0001 | 0.0010 | 0 |
| Pluto+ | 10 | 244 | 101 | 0.0003 | 0.0009 | 0 |
| Pluto+ | 20 | 488 | 101 | 0.0010 | 0.0009 | 0 |
| Pluto+ | 30.72 | 750 | 101 | 0.0020 | 0.0010 | 0 |
| Pluto+ | 61.44 | 1023 | 148 | 0.0035 | 0.0015 | 0 |

So the I/Q frames are phase coherent and exactly `nint * 4096` samples
apart, with no lost frame. The arrival interval over the websocket matches
the frame period (largest gap in any run 143 ms for a 100 ms period, once, at
20 MS/s on the Pluto+; no phase jump there, so it was delivery jitter). The phase of a single tone between frames is not predictable
here (second difference 0.25 to 0.6 rad rms, the reference drift).

## Combined with the open fixes (tezuka firmware, both boards, 2026-10-16)

The firmware (tezuka_fw v0.3.23) does not build its bitstreams from the
`pluto_iio` and `plutoplus_iio` projects of this repository but from the
`tezuka` project (`maia-hdl/projects/tezuka`) of the `refactor` line, which
has its own block design. The same HP0/HP3 scheme as above (raw capture on
HP3 with the CPU clock, I/Q on HP0 with the maia_sdr clock and its own reset
generator, same reset_timing constraints) was applied there, in
`projects/common/maia.tcl`, on a branch that combines this PR with the open
fix PRs (#14 to #23) and the DDC routing patches of maia-httpd
(`test/allfixes-pr12-iqfix` in the fork). Images: tezuka_fw v0.3.23 plus the
eight open tezuka_fw fix PRs, the device-tree nodes and these bitstreams
(`test/allfixes-pr12-layout`, `test/allfixes-pr12-iqfix` in the fork); Pluto
`v0.3.23-16-g8a1b74d`, Pluto+ `v0.3.23-15-g9ebeaf2`. Timing (Vivado 2023.2):
Pluto WNS +0.192 ns, WHS +0.015 ns, no failing endpoints; the Pluto+ build is
the one verified earlier (WNS +0.069 ns, WHS +0.025 ns).

Run on both boards over the cable (the other board transmits), all passing:
BIST check, `rf_iq_check.py`, `rf_phase_check.py` and
`rf_iq_frame_phase_check.py` at 2.5, 10, 20, 30.72 and 61.44 MS/s.
Frame-to-frame rotation of the I/Q waterfall, measured minus predicted:
Pluto -0.0017 to +0.0003 rad (scatter 0.0009 to 0.0019 rad), Pluto+ -0.0001
to +0.0023 rad (scatter 0.0008 to 0.0013 rad), no frame off by more than
0.3 rad. OFDM log correlation of magnitude and I/Q waterfalls 0.989 to
0.999 (Pluto, RX gain 52). Phase-derived minus time-domain frequency: Pluto
-18 to +6 Hz, Pluto+ -8 to +3 Hz, within the check's 150 Hz tolerance and
mostly within the measured drift of the two board references.

Notes: (1) the phase check's windowed-FFT model comparison showed a 175 to
180 degree phase and 53 to 57 dB amplitude error on one tone in about nine
(Pluto 2.5 MS/s, in one case together with a 180 degree I/Q-versus-raw
difference); the check does not use it as a pass criterion, I believe it is
a bin close to a null of the model with almost no signal but did not prove
it. (2) On the Pluto+ the first BIST run after writing the SD card showed
the same peak bin for the three tones; seven later runs, two of them after a
clean reboot, were correct, and I do not have an explanation. (3) Not tested:
absolute level (dBm) and boards other than these two.

## Bugs found with these tests (fixed in this PR)

- `DmaBRAMWrite`: for 32-bit data the write address was shifted one bit
  (`Signal(11) << 6` is 18 bits wide, since a constant shift widens by
  `2**bits(shift) - 1`; the 64-bit case, shift 7, happened to be right).
  The I/Q DMA wrote outside the DDR (OKAY responses) and the waterfall
  buffers stayed stale. The cocotb tests used bases that hide it;
  `test/test_dma.py` checks the addresses.
- Raw capture wrote every sample three times: `strobe_in` is a one-cycle
  `sync` pulse, which lasts three `clk3x` cycles, and the recorder (in
  `clk3x`) saw all three. The tap now registers in `sync` and the strobe is
  gated with `common_edge_3x`. `test_raw_capture_strobe_is_single_pulse`
  covers it.
- The raw tap needed a pipeline register to meet timing at 187.5 MHz.

## Not tested

- Absolute level (dBm); the scale is uncalibrated.
- Boards other than the Pluto+ and the original Pluto (the DMA masters are
  not wired on the others in this repository).
- Modulated signals against the raw capture beyond peak position.
