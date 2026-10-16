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
needs reserved-memory nodes for their buffers. On the Pluto+ test build
the raw master is on HP3 and the I/Q master on HP0 (through an
interconnect), with a clock association of the raw master in
`package_ip.tcl` and implementation-only false paths for the reset.
Other boards need the same wiring.

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
  through the cable; magnitude, I/Q and raw capture peaks agree, OFDM log
  spectra of magnitude and I/Q correlate.
- `rf_phase_check.py --fs <rate>`: phase check with CW tones (see the
  docstring): frame-to-frame phase advance against a time-domain frequency
  measurement, bin-to-bin phase against a windowed-FFT model, I/Q waterfall
  against raw capture.

## Results (Pluto+, 40 dB cable, 2.4 GHz LO, 2026-10-16)

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

- Phase between I/Q waterfall frames (they are `number_integrations`
  frames apart).
- Absolute level (dBm); the scale is uncalibrated.
- Boards other than the Pluto+ (the DMA masters are not wired on the
  others in this repository).
- Modulated signals against the raw capture beyond peak position.
