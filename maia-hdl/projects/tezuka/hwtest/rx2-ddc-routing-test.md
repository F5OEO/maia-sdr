# RX2 with DDC routing on (Pluto+, 2r2t)

`cs12_cs8.tcl` clocks the RX2 channel pair (`cs12_8mux_chan1`) with RX1's `valid_in`. With DDC routing on,
that is the DDC output strobe, so RX2 was picked every decimation-th sample with no filter and no mixer.

`rx2test.py <label> <host>` steps the AD9363 BIST tone (mode 2, injected into RX) through its four
frequencies, (i+1) * fs/32. For each one it captures `voltage0..3` in CS16, first with routing off, then
with routing on and the DDC tuned 100 kHz below the tone. It reports the strongest frequency and level per
channel pair. The Pluto+ was switched to `mode=2r2t` (U-Boot environment) to expose RX2 and switched back
afterwards. The default `1r1t` does not expose `voltage2/3`, so stock setups do not see this.

Results (30.72 MS/s, DDC decimation 20, DDC output 1.536 MS/s):

| BIST tone | RX1 (DDC), routing on | RX2, routing on, before | RX2, routing on, this change | RX2 alias of an unfiltered pick |
|---|---|---|---|---|
| 960 kHz | +100 kHz, -14.4 dBFS | -576 kHz, -6.0 dBFS | all zero | -576 kHz |
| 1.92 MHz | +100 kHz, -14.4 dBFS | +384 kHz, -6.0 dBFS | all zero | +384 kHz |
| 2.88 MHz | +100 kHz, -14.4 dBFS | -192 kHz, -6.0 dBFS | all zero | -192 kHz |
| 3.84 MHz | +100 kHz, -14.4 dBFS | -768 kHz, -6.0 dBFS | all zero | -768 kHz |

**Before:** every tone appeared in RX2 at full level, exactly at its alias. **With this change:** RX2 carries
zeros while routing is on. With routing off, RX1 and RX2 both show each tone at its true frequency, so normal
2r2t use is unchanged.

**Mixed packing modes:** RX1 and RX2 in different CS8/CS12/CS16 modes would break the shared `fifo_wr_en`,
but userspace cannot request them. The driver accepts only one channel, one pair (`voltage0+1` or
`voltage2+3`) or all four; every other mask fails with `Unable to allocate buffer: Invalid argument`.

Raw data: `results/plutoplus-before-2r2t-rx2.json`, `results/plutoplus-rx2zero-2r2t-rx2.json`. In the
before file, the routing-off entries for tones 2-4 are not valid: the test script did not switch routing
off between cases. That was fixed before the after run. The routing-on entries are valid.
