---
date: 2026-05-17T00:16:04+0200
author: Tom Hensel
commit: a31ec68
branch: refactor
repository: maia-sdr
topic: "Vivado 2025.2 CI Pipeline — Bitstream Build Fixes & All Boards"
tags: [vivado, ci, bitstream, docker, libudev, webtalk, ghcr]
status: in_progress
last_updated: 2026-05-17T00:16:04+0200
last_updated_by: Tom Hensel
type: feature_development
---

# Handoff: Vivado CI Bitstream Build — Complete Pipeline

## Task(s)

### 1. CI Bitstream Build Pipeline ✅

- fishball7020 CI run **succeeded** (run 25972643835) — 0 synth errors, 0 DRC errors
- pluto CI run **succeeded** (part of all-boards run 25973425691)
- All 5 environment bugs found, fixed, and verified in CI
- All 10 boards triggered sequentially — currently: pluto ✅, plutoplus 🔄, 8 queued

### 2. Environment Fixes (all verified) ✅

| Fix                                     | Purpose                                | Status |
| --------------------------------------- | -------------------------------------- | ------ |
| `rm libudev* + ldconfig`                | Prevent WebTalk realloc crash          | ✅     |
| `: > /etc/os-release`                   | Prevent system.v Verilog syntax errors | ✅     |
| `apt-get install libpixman-1-0`         | Missing Vivado dep                     | ✅     |
| Source `.settings64-Vivado.sh` directly | Missing Vitis dir                      | ✅     |
| `MALLOC_CHECK_=0`                       | Vivado glibc heap corruption           | ✅     |

### 3. Workflow Improvements ✅

- Bumped `actions/checkout@v4` → `@v6`, `actions/upload-artifact@v4` → `@v7`
- Added timing/utilization/power reports to build.ci.tcl
- Fixed reports artifact paths

### 4. Upstream vivado-docker synced ✅

- `gretel/vivado-docker` fork synced with `filmil/vivado-docker`
- Tagged `v2025.2`

### 5. Pending: GHCR image push, \_iio/\_sync variants, fishball_mini boards

## Critical References

- `.github/workflows/maia-hdl-bitstream.yml` — CI workflow with all fixes
- `maia-hdl/ci/build.ci.tcl` — build script (Phase 0 IP copy + ADI project + reports + write .bin)
- `/Users/tom/.agents/skills/vivado-docker/SKILL.md` — detailed issue reference

## Recent changes

- `.github/workflows/maia-hdl-bitstream.yml:49-106` — all env fixes, action bumps, reports upload
- `maia-hdl/ci/build.ci.tcl:56-66` — added report_timing_summary, report_utilization, report_power + write_bitstream

## Learnings

- **Root cause of all realloc crashes**: Vivado WebTalk calls `udev_enumerate_scan_devices()` via `XilReg::Utils::GetHostInfo()` → `GetRegInfoWebTalk()`. Fix: `rm /lib/x86_64-linux-gnu/libudev.so.1*; ldconfig`. The upstream `filmil/vivado-docker` uses a libudev stub + `XILINX_LOCAL_USER_DATA=no` instead.
- **Vivado BD generator bug**: Dumps `/etc/os-release` content raw into generated `system.v` header. Multi-line VERSION field breaks Verilog syntax. Fix: `: > /etc/os-release`.
- **tezuka_fw deployment format**: tezuka_fw expects `.xsa` files (Xilinx Shell Archive) via `update_bitstream.sh`, not `.bin` files. Our CI produces `.bin` (for UHD). The `_iio` standalone projects deploy `.xsa`. Need to decide format for maia-sdr bitstreams on tezuka.
- **GitHub Actions runtime**: ubuntu-24.04 runner was slower than ubuntu-latest. Sequential builds for all 10 boards take ~6+ hours.
- **GHCR push**: Push hangs from home connection (slow upload, manifest step times out). Layers partially uploaded — retry might work.
- **Action versions**: `actions/checkout@v6` and `actions/upload-artifact@v7` are latest (Node 24). Use major version tags only.

## Artifacts

- `.github/workflows/maia-hdl-bitstream.yml` — CI workflow
- `maia-hdl/ci/build.ci.tcl` — build script
- `/Users/tom/.agents/skills/vivado-docker/SKILL.md` — reference skill
- Memory facts: `project.maia-sdr.vivado-ci`, `project.maia-sdr.vivado-ci.success`, `project.maia-sdr.pluto-builds`, `project.maia-sdr.tezuka-bitstream-format`
- Memory lessons: 3 entries for `vivado-docker` category

## Action Items & Next Steps

1. **[Wait for CI]** Let all-boards run 25973425691 finish (sequential, ~6h total). Monitor for failures.
2. **[GHCR push]** After CI done, retry `docker push ghcr.io/gretel/maia-sdr/xilinx-vivado:2025.2`. Some layers already exist — only manifest remains. If push works, switch workflow to `docker pull` instead of release chunks.
3. **[Add missing boards]** Add `fishball_mini` (7010) and `fishball_mini_7020` to CI workflow → 12 boards matching tezuka_fw configs.
4. **[Investigate _iio/_sync]** These are standalone ADI projects with own Makefiles, not part of tezuka meta-project. They deploy to tezuka_fw as `.xsa`. Need separate CI pipeline if desired.
5. **[Deployment format]** Decide whether maia-sdr bitstreams should produce `.xsa` for tezuka_fw or stay as `.bin`.
6. **[Cache]** Consider adding `actions/cache` for pip packages to save ~30s per build.

## Other Notes

- Fork: `gretel/maia-sdr`. Upstream: `F5OEO/maia-sdr`. Remote: `fork` for push.
- vivado-docker fork: `gretel/vivado-docker` synced to `filmil/vivado-docker` main.
- Local Vivado images: `xilinx-vivado:2025.2` (19 GB), `vivado-base:2025.2` (183 MB).
- Release chunks: 10 x 1.9 GB at `vivado-2025.2` tag on `gretel/maia-sdr`.
- The upstream `filmil/vivado-docker` already has libudev stub (commit 216744f). Our os-release/Vitis/libpixman fixes are specific to trimmed install approach.
