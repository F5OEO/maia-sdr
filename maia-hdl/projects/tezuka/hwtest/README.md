# Pluto/Pluto+ hardware test: CS12 vs DDC routing, fastlock sweeper

Host-driven test for the CS12 `zero_count` / DDC-routing GPIO conflict and for
`sweeper_it` (see `../doc/review-v0.3.23-fpga.md`, findings F1 and F4).
It talks to a running tezuka_fw image over SSH (root/analog) and HTTP.

| File | Runs on | Purpose |
|---|---|---|
| `hwtest.py <label> [host]` | host | Runs all checks, writes `results/<label>.json`; `FS=61440000` sets the AD9363 rate for the run |
| `wfprofile.py <host> [n]` | host | Reads `/waterfall` frames; `f[0]` is the fastlock profile |
| `agcmon.c` | board | Samples Zynq GPIO bank 2 `DATA_RO` (EMIO pad readback) for N seconds |

Build `agcmon` with the Buildroot cross-compiler of the image under test:

    output/plutoplus/host/bin/arm-linux-gcc -O2 -Wall -o agcmon agcmon.c

Host requirements: `sshpass`, `curl`, Python with `websockets`.

## What it checks

1. **Sweeper cadence**: 48 `/waterfall` frames; the profile in `f[0]` must step by 1 per frame through 0..7.
2. **Sweeper pins**: GPIO 63-66 (CTRL_IN1..3, EN_AGC) are made PS outputs driven low, as the tezuka sweep
   mode does for 63-65, and the pads are sampled for 10 s. CTRL_IN1..3 must show all 8 profiles; EN_AGC
   must stay low. The lines are returned to inputs afterwards (`gpioget`).
3. **CS12 with DDC routing**: routing is switched with maia-httpd `PATCH /api/ddc/config {"enabled":…}`
   (axi_ad9361 `up_adc_gpio_out` bit 0). For routing off and on it captures CS16 (`voltage0 voltage1`)
   and CS12 (`voltage1` only) with `iio_readdev` on the board, and checks the CS12 sync bursts
   (20-byte magic every 786432 bytes through util_cpack2). Routing is disabled again at the end.

## Results (Pluto+, 2026-10-11)

Both images are tezuka_fw v0.3.23 (2dde77d) built locally; they differ only in the Pluto+ `tezuka.xsa`
(same kernel, same `devicetree.dtb` md5 `ba5c7f5c…`).

| Check | v0.3.23 shipped bitstream | this branch (bf83f60) |
|---|---|---|
| `/boot/system_top.bin` md5 | `618a5b4a…` | `2e21d04b…` |
| CS12, routing on | **0 bytes**, `Unable to refill buffer: Connection timed out (110)` | 3932160 bytes, 5 sync bursts, all gaps 786432; 10/10 repeats regular |
| CS12, routing off | 3932160 bytes, gaps 786432 | 3932160 bytes, see note below |
| CS16, routing off / on | OK / OK (≈1.3-1.4 MS/s measured incl. start-up, DDC 1.536 MS/s) | OK / OK |
| EN_AGC pad (GPIO 66 forced output-low), 10 s | **25 rising edges, high 12.3 %** (1 frame in 8) | 0 rising edges, high 0 % |
| CTRL_IN1..3 pads | all 8 values, ≈12.5 % each | all 8 values, ≈12.5 % each |
| `/waterfall` profile steps | 0..7, 46 steps of +1, one repeated value | 0..7, 47 steps of +1 |

Raw data: `results/v0.3.23-baseline.json`, `results/v0.3.23-fixed-bf83f60.json`.

## Results (original Pluto, 2026-10-11)

Baseline is the official tezuka_fw v0.3.23 release (CI build of 2dde77d) in QSPI. The fixed image is
v0.3.23 built locally with only the Pluto `tezuka.xsa` replaced, flashed as `pluto.frm` over USB mass storage.

| Check | v0.3.23 release | this branch (bf83f60) |
|---|---|---|
| CS12, routing on | **0 bytes**, `Unable to refill buffer: Connection timed out (110)` | 3932160 bytes, 5 sync bursts, gaps 786432; 10/10 repeats regular |
| CS16, routing off / on | OK / OK | OK / OK |
| EN_AGC pad (GPIO 66 forced output-low), 10 s | **9 rising edges, high 9.6 %** | 0 rising edges, high 0 % |
| CTRL_IN1..3 pads | all 8 values | all 8 values |
| `/waterfall` profile steps | 0..7, 47 steps of +1 | 0..7, 47 steps of +1 |

The irregular wideband CS12 gaps with routing off (see the note below) also show up on the official
release (one gap of 738352 bytes), so they come from the capture path, not from this change.

Raw data: `results/pluto-v0.3.23-release.json`, `results/pluto-v0.3.23-fixed-bf83f60*.json`.

## 61.44 MS/s (both boards, fixed bitstream)

The tables above use the default 30.72 MS/s. The same test at the AD9363 maximum of 61.44 MS/s
(`FS=61440000`, DDC output 3.072 MS/s) passes on both boards: CS12 with routing on gives
regular sync bursts, EN_AGC shows 0 edges, CTRL_IN1..3 show all 8 profiles, and the `/waterfall`
profile steps by +1. Raw data: `results/{plutoplus,pluto}-fixed-bf83f60-61M44.json`.

## Note on CS12 with routing off

On-board `iio_readdev` writing to tmpfs sustains about 39 MB/s. CS12 needs 3 bytes per complex sample,
so about 92 MB/s at 30.72 MS/s and about 184 MB/s at 61.44 MS/s. Wideband CS12 captures in this test
therefore lose data (irregular sync gaps: 5/10 at 30.72 MS/s, most captures at 61.44 MS/s, 0/10 at
5 MS/s and at the DDC rate; `results/v0.3.23-fixed-bf83f60-cs12-{rate,repeat}.json`). The official
release on the original Pluto shows the same, and this path is not touched by the change (`zero_count`
was 0 there before and after). It is a limit of the capture tool, not an FPGA defect.

The single repeated profile value on the shipped bitstream is consistent with the unsynchronised
`profile_o` crossing, but one occurrence is not proof.
