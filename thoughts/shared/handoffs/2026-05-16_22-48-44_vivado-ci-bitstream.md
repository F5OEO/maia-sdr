---
date: 2026-05-16T22:48:44+0200
author: Tom Hensel
commit: ede8c02
branch: refactor
repository: maia-sdr
topic: "Vivado 2025.2 CI Pipeline — Bitstream Build Fixes & History Rewrite"
tags: [vivado, ci, bitstream, docker, libudev, webtalk]
status: in_progress
last_updated: 2026-05-16T22:48:44+0200
last_updated_by: Tom Hensel
type: feature_development
---

# Handoff: Vivado 2025.2 CI Bitstream Build

## Task(s)

### 1. CI Bitstream Build Pipeline (fishball7020) 🔄

- fishball7020.bin (2.5 MB) generated successfully via local OrbStack (QEMU) build
- All 5 CI environment bugs found and fixed (see Learnings)
- CI workflow updated with all fixes at `.github/workflows/maia-hdl-bitstream.yml`
- CI runs kept failing on runner speed (free-disk step 10-15 min, download 25+ min stuck) — GitHub Actions was slow today
- Local build success proves the environment fixes are correct

### 2. vivado-docker skill created ✅

- `/Users/tom/.agents/skills/vivado-docker/SKILL.md` documents all issues, fixes, timing, env vars

### 3. History purge ✅

- All old CI runs deleted (19+ runs)
- Stale cron jobs cleaned up

## Critical References

- `.github/workflows/maia-hdl-bitstream.yml` — CI workflow with all fixes
- `maia-hdl/ci/build.ci.tcl` — build script (Phase 0 IP copy + ADI project flow + write .bin)
- `/Users/tom/.agents/skills/vivado-docker/SKILL.md` — detailed issue reference

## Recent changes

- `.github/workflows/maia-hdl-bitstream.yml:62-85` — added os-release blank, libudev removal, libpixman install, MALLOC_CHECK_=0, direct Vivado settings source
- `maia-hdl/ci/build.ci.tcl` — Phase 0 copies custom IPs into adi-hdl/library/ before Vivado

## Learnings

- **Root cause of all realloc crashes**: Vivado WebTalk calls `udev_enumerate_scan_devices()` via `XilReg::Utils::GetHostInfo()` → `GetRegInfoWebTalk()`. In Docker without real udev, glibc heap corrupts → `realloc(): invalid pointer`. Fix: `rm /lib/x86_64-linux-gnu/libudev.so.1.7.2 /lib/x86_64-linux-gnu/libudev.so.1 && ldconfig`. The upstream `filmil/vivado-docker` uses a libudev stub + `XILINX_LOCAL_USER_DATA=no` instead.
- **Vivado BD generator bug**: Dumps `/etc/os-release` content raw into generated `system.v` header. Multi-line VERSION field breaks Verilog syntax. Fix: `: > /etc/os-release` before Vivado.
- **Missing libpixman-1-0**: Vivado `libxv_tcltasks.so` needs `libpixman-1.so.0`. Not in minimal base image.
- **Vitis settings issue**: Trimmed install has no Vitis dir. Top-level `settings64.sh` sources `.settings64-Vitis_for_HLS.sh` → fails. Fix: source Vivado's own `.settings64-Vivado.sh`.
- **MALLOC_CHECK_=0**: Vivado 2025.2 has glibc heap corruption issues. Mitigated by MALLOC_CHECK_=0 env var.
- **os-release at `/etc/os-release` in Docker**: Ubuntu 22.04 has `VERSION="22.04.5 LTS (Jammy Jellyfish)"` which causes the multi-line Verilog breakage.
- **GitHub Actions today**: Runners were very slow (free-disk 10-15 min, download 25+ min). ubuntu-24.04 runner was slower than ubuntu-latest. Use ubuntu-latest for better performance.
- **`gh release download` speed**: 1 GB chunk took 4.8 min from my home connection (~3.5 MB/s). CI runner should be faster on internal network.

## Artifacts

- `/Users/tom/src/uhd/maia-sdr/fishball7020.bin` — generated bitstream (2.5 MB)
- `/Users/tom/src/uhd/maia-sdr/fishball7020.bit` — generated bitstream (2.5 MB)
- `.github/workflows/maia-hdl-bitstream.yml` — CI workflow with all fixes
- `maia-hdl/ci/build.ci.tcl` — build script
- `/Users/tom/.agents/skills/vivado-docker/SKILL.md` — detailed reference
- Memory lessons: 3 entries for vivado-docker category

## Action Items & Next Steps

1. **[CI] Retry CI run on GitHub** when runners are faster (weekday non-peak hours). Use: `gh workflow run maia-hdl-bitstream.yml --repo gretel/maia-sdr --ref refactor -f projects="fishball7020"`
2. **[Upstream] Sync + bump gretel/vivado-docker** with latest upstream changes from filmil/vivado-docker. The fork at `~/src/uhd/vivado-docker` has multiple PR branches.
3. **[Image] Optionally rebuild vivado-base with libpixman-1-0** baked in to avoid apt-get at runtime. Add to the Dockerfile: `libpixman-1-0` package.

## Other Notes

- Fork: `gretel/maia-sdr` (user: Tom Hensel). Upstream: `F5OEO/maia-sdr`. Remote: `fork` for push, `origin` for fetch-only.
- External volume: `/Volumes/MacroSmol/work/` — 296 GB free.
- Vivado image chunks at GitHub Release `vivado-2025.2` on `gretel/maia-sdr` (10 chunks, 19 GB).
- Local Vivado image: `xilinx-vivado:2025.2` (19 GB) and `vivado-base:2025.2` (183 MB).
- The upstream `filmil/vivado-docker` already has the libudev stub fix (commit 216744f by @gretel). It does NOT have os-release blanking, libpixman, Vitis settings workaround, or MALLOC_CHECK_=0 — these are specific to our trimmed install approach.
- The upstream uses a full Vivado install (200+ GB) via installer, not our trimmed 41 GB approach.
