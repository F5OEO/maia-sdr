# Review: tezuka Pluto/Pluto+ FPGA design (bitstream of tezuka_fw v0.3.23)

Static review of the FPGA side of the Pluto and Pluto+ bitstreams shipped in tezuka_fw v0.3.23
(2dde77d, "Update bistreams with maia 22d590ce…"). For Pluto/Pluto+ the design source is identical
at `refactor` 22d590c, f7092ba and 9c1cd64, with ADI hdl cf81ab15 and maia-hdl IP `maia_iio_lite`
0.6.1. Every finding below was checked against the source and against the `system.hwh` inside the
shipped `.xsa`. F1 and F4 were also tested on a Pluto+ (see `../hwtest/README.md`).

The upstream ADI interface (axi_ad9361 CMOS 2R2T, util_wfifo/rfifo, util_cpack2/upack2, axi_dmac) and
the maia-hdl DSP cores are used as intended. The device trees match the address map in the `.hwh`.
The findings are in the tezuka glue around them.

## Fixed in this branch

### F1: one GPIO bit drives both DDC routing and the CS12 packer reset
`maiafirtoiq.tcl` (`decim_slice`, default bit 0) and `cs12_cs8.tcl` (`cs12_zero_count_slice`,
DIN_FROM/TO 0) both sliced `axi_ad9361/up_adc_gpio_out` bit 0. maia-httpd's DDC routing switch
(`PATCH /api/ddc/config {"enabled":true}`, register 0x790200BC) therefore also held `cs12_8mux` in
`zero_count`, so CS12 (`voltage1` only) produced no data while routing was on.
**Fix:** `zero_count` moves to bit 3 (bits 1-2 are used by `sync.tcl`), with a matching false path.
**Hardware:** the shipped bitstream reports `Unable to refill buffer: Connection timed out`
with 0 bytes; the fixed bitstream returns CS12 with correct sync bursts (10/10 captures).

### F4: `sweeper_it` is clocked by a data signal, and its output overflows into EN_AGC
`sweeper.tcl` connected `sweeper_io/clk` to `maia_sdr/clk_fastlock_out`, which is the spectrometer
`end_fft` (`integrator.nearly_end`). That signal is a register output in the maia_sdr clock domain,
not a clock: it has no BUFG and no clock constraint, so the sweeper logic is untimed.
`profile_o` went back into the same domain (`fastlock_profile_in`, read by the spectrometer DMA)
without synchronisation, the reset came from `axi_ad9361/rst` (l_clk domain), and `gpio_o` had no reset.
Separately, `gpio_o <= (count + 1) << 9` is evaluated at the 64-bit width of `gpio_o`, so
`count == 7` sets bit 12 (`gpio_en_agc` in `system_top.v`) instead of wrapping inside 11:9.
In stock v0.3.23 EMIO 66 stays an input: the ADI driver does not request `en_agc-gpios`, and the
sweep mode in `api_controller.sh` sets only 63-65. So the bug is latent. Any PS code that drives
EN_AGC would see it go high for one frame in eight.
**Fix:** clock from `maia_sdr_clk/clk_out1`; `end_fft` becomes a rising-edge step enable, which keeps
the old cadence and the meaning of `profile_o` (the profile of the finished spectrum). The reset is
synchronised in the module, with a false path only on the synchroniser preset (`sweeper_it.xdc`).
`gpio_o` is now an explicit 3-bit field `{52'd0, count + 1, 9'd0}` with a reset.
**Hardware:** with GPIO 66 forced to output-low, EN_AGC on the shipped bitstream: 25 rising edges
in 10 s, high 12.3 %. On the fixed bitstream: 0 edges. CTRL_IN1..3 show all 8 profiles on both, and
the `/waterfall` profile steps by +1 per frame. The testbench `../../common/tb/sweeper_it_tb.v`
covers the wrap and the step-per-edge behaviour.

Both boards meet timing after the change (Vivado 2023.2: Pluto WNS +0.210 ns, Pluto+ +0.175 ns).

## Open (not changed here)

### F2: DDC I and Q cross clock domains in two independent async FIFOs
`maiafirtoiq.tcl` uses separate `axis_data_fifo` instances `interclk_i` and `interclk_q` (maia clock to
divclk). Their outputs go to `cs12_8mux` with `valid_in = mux_decim_i/valid_out` only, and
`mux_decim_q/valid_out` and both `m_axis_tready` are unconnected. The two gray-pointer synchronisers
resolve independently, so Q can occasionally be taken one sample late (sporadic I/Q misalignment on the
DDC path). `s_axis_aresetn` comes from `sys_rstgen` (100 MHz) while `s_axis_aclk` is the maia clock.
Suggested fix: one 32-bit FIFO carrying `{Q, I}`, reset synchronous to its clock. Status: plausible,
needs a tone test on hardware.

### F17: Pluto+ RX2 is decimated without filtering when DDC routing is on
`cs12_8mux_chan1` takes raw RX2 (`dout_data_2/3`) but `valid_in = mux_decim_i/valid_out`. With routing
on, RX2 is sampled at the DDC rate with no filter or mixer, so it aliases. Mixed per-pair modes
(e.g. RX1 CS12, RX2 CS16) feed `util_cpack2` with one shared `fifo_wr_en = valid0 | valid1`.

### F3: the CS12 sync frame replaces samples
`cs12_sync_frame.v` replaces one 8-sample burst every `SYNC_PERIOD_SAMPLES` (262144) with
MAGIC+COUNTER. Hosts must blank or interpolate it, and the period is a synthesis parameter with no
register to read it back.

### F5: the DDC output to IIO is floor-truncated to 12 bits
`maia_sdr.py`: `decim_re_out.eq(self.ddc.re_out >> 4)`. The arithmetic shift has a -0.5 LSB DC bias
and throws away the decimation gain even in CS16 mode. Suggested: round (+8 before >> 4); pass 16 bits
for CS16 and narrow only in the CS12/CS8 packer.

### F6: dead CDC instance
`maia_sdr.py`: the outputs of `ddciq_cdc = RxIQCDC('sync', 'sampling', 16)` are unused (their consumers
are commented out). It duplicates the Vivado `interclk_*` FIFOs.

### N1: CS8 arithmetic and mode selection
`cs12_cs8mux.v`: `{{2{I0[11]}}, I0[11:0]} + err_i` mixes an unsigned concatenation with a signed
register. It is correct modulo 2^13, but `$signed()` would make the intent explicit. The mode is chosen
by IIO channel enables (voltage0 only = CS8, voltage1 only = CS12, both = CS16), so a standard libiio
client that enables one channel receives packed data.

### N2: stale constraint
`boards/{pluto,plutoplus}/system_constr.xdc`: `set_false_path -from .../manual_decim/...` refers to a
cell that is not in the design (Vivado reports 12-4739 on every build).

### Reproducibility
The provenance of the shipped `.xsa` is recorded only in the tezuka_fw commit message, with nothing
readable from the bitstream. `projects/tezuka/Makefile` hard-codes `DEST=/media/hp-z2-dev/...`.
