---
date: 2026-05-16T14:30:11+0200
author: Tom Hensel
commit: 6dce4f5
branch: refactor
repository: maia-sdr
topic: "Vivado 2025.2 CI Pipeline — Bitstream Build Fixes & History Rewrite"
tags: [vivado, ci, github-actions, fpga, bitstream, ghcr]
status: in_progress
last_updated: 2026-05-16T14:30:11+0200
last_updated_by: Tom Hensel
type: feature_development
---

# Handoff: Vivado CI Bitstream Build Fixes

## Task(s)

### 1. CI Bitstream Build Pipeline (fishball7020) 🔄

- Run [25961929897](https://github.com/gretel/maia-sdr/actions/runs/25961929897) — currently at "Free disk space on runner" step
- 6 previous attempts all failed with various errors (see Learnings)
- Current run uses standard ADI flow (adi_project → adi_project_run with launch_runs)

### 2. History Rewrite ✅

- Squashed 18 noisy commits → 5 milestone commits
- Removed reverted approaches (system_bd.tcl workaround)
- Force-pushed to gretel/maia-sdr:refactor

### 3. Trimmed Vivado Docker Image ⚠️

- 41 GB trimmed install at `/Volumes/MacroSmol/work/xilinx-split/Xilinx/`
- `vivado-base:2025.2` was pruned — needs rebuild to create trimmed image
- Not pushed to GHCR yet (split-layer approach pending)

### 4. Split-Layer GHCR Image ⚠️

- 6-layer Dockerfile drafted at `/Volumes/MacroSmol/work/xilinx-split/vivado-split.dockerfile`
- Not built (OrbStack VM ran out of space during build)

## Critical References

- `.github/workflows/maia-hdl-bitstream.yml` — CI workflow
- `maia-hdl/ci/build.ci.tcl` — Phase 0 (IP copy) + sources system_project.tcl → write .bin
- `maia-hdl/projects/tezuka/system_project.tcl` — guarded axi_ad9361_delay.tcl (reverted)
- `/opt/homebrew/lib/node_modules/@juicesharp/rpiv-pi/skills/resume-handoff/SKILL.md` — resume mechanism

## Recent changes

- `.github/workflows/maia-hdl-bitstream.yml` — clean workflow, add amaranth-yosys dep, remove GHCR push, remove cancel-in-progress
- `maia-hdl/ci/build.ci.tcl` — Phase 0 copies custom IPs into adi-hdl/library/ before Vivado, then sources system_project.tcl (standard ADI flow), opens impl_1 and writes .bin
- `maia-hdl/projects/tezuka/system_project.tcl` — added/removed guard for axi_ad9361_delay.tcl when ADI_SKIP_SYNTHESIS set (now reverted — use standard flow)
- `maia-hdl/projects/tezuka/system_bd.tcl` — briefly added IP repo path workaround (reverted — replaced by Phase 0 copy approach)
- `.pi/agent/AGENTS.md` — revised Tool Use section with comprehensive tool catalog

## Learnings

- **IP discovery**: `adi_project` only searches `$ad_hdl_dir/library/` for IPs. Custom IPs (maia-sdr, dvbs2rx) must be in that path. Easiest fix: Phase 0 copies component.xml dirs from `maia-hdl/ip/` into `adi-hdl/library/` before Vivado starts. system_bd.tcl tweak with update_ip_catalog was unreliable.
- **Rosetta vs x86_64**: In-process synth/impl (bypassing launch_runs) is ONLY needed on Apple Silicon (Rosetta emulation). CI runners are x86_64 Ubuntu — launch_runs works natively. Our first 6 CI attempts all failed because we kept the Rosetta workaround.
- **generate_target issue**: `generate_target all [get_ips]` fails because nested block-design IPs (system_GND_1_0) can't be generated individually. Removing this call and letting synth_design auto-elaborate is correct.
- **current_design timing**: `set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]` fails before synthesis because no design exists. Must move after synth_design.
- **GitHub auto-cancel**: Force-push cancels in-progress CI runs, losing 24 GB Vivado download cache. Fix: `cancel-in-progress: false` in workflow concurrency.
- **OrbStack disk limits**: Building 41-53 GB Docker images on OrbStack repeatedly hits VM disk full. `docker export | docker import` avoids commit hangs. External volume `/Volumes/MacroSmol/work/` must have >100 GB free for these operations.
- **macOS sed**: `sed -i ''` requires empty backup extension AND separate `-e` flags for each expression. Multi-line GIT_SEQUENCE_EDITOR scripts need careful escaping.

## Artifacts

- `.github/workflows/maia-hdl-bitstream.yml` — CI workflow (5 milestone commits)
- `maia-hdl/ci/build.ci.tcl` — build script (Phase 0 copy + source system_project.tcl + write .bin)
- `maia-hdl/projects/tezuka/system_project.tcl` — standard ADI flow (guard reverted)
- `/Volumes/MacroSmol/work/xilinx-split/Xilinx/` — 41 GB trimmed Vivado install on host
- `/Volumes/MacroSmol/work/xilinx-split/vivado-split.dockerfile` — 6-layer split Dockerfile
- `/Volumes/MacroSmol/work/FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157_1.tar` — 96 GB original installer
- `~/.agent/skills/vivado-docker/SKILL.md` — detailed build instructions
- `.pi/agent/AGENTS.md` — revised Tool Use section

## Action Items & Next Steps

1. **[CI] Monitor run 25961929897** — currently at "Free disk space". If fishball7020 builds successfully (should take 30-60 min), trigger remaining 9 projects. If it fails, check error — likely Vivado version check or license issue.

2. **[Image] Rebuild vivado-base:2025.2** — was pruned during Docker cleanup. Needed before building trimmed image:

   ```bash
   docker build --platform linux/amd64 -t vivado-base:2025.2 -f- . <<'DEOF'
   FROM ubuntu:22.04
   ENV DEBIAN_FRONTEND=noninteractive
   RUN echo "dash dash/sh boolean false" | debconf-set-selections && \
       apt-get update && apt-get install -y \
       build-essential gcc g++ libc6-dev libncurses5 locales xz-utils \
       libglib2.0-0 libsm6 libxext6 libxrender1 libxrandr2 libfontconfig1 \
       libxi6 libxcursor1 libxft2 libdbus-1-3 libpcap0.8 python3 python3-pip \
       libtinfo5 libncurses5-dev locales iproute2 netbase && \
       locale-gen --purge en_US.UTF-8 && \
       apt-get clean && rm -rf /var/lib/apt/lists/*
   DEOF
   ```

3. **[Image] Build trimmed Docker image** — from `/Volumes/MacroSmol/work/xilinx-split/Xilinx/`:

   ```bash
   cd /Volumes/MacroSmol/work/xilinx-split
   docker build --platform linux/amd64 -t xilinx-vivado:2025.2-trimmed .
   ```

   Then save → split → upload as new GitHub Release.

4. **[Image] Build split-layer GHCR variant** — to bypass 10 GB layer limit. Use the 6-layer Dockerfile at `/Volumes/MacroSmol/work/xilinx-split/vivado-split.dockerfile`. May need to adjust layer sizes after actual dir size inspection.

5. **[CI] Disable other workflow files** — F5OEO/maia-sdr fork has 6 other workflows (maia-hdl.yml, maia-httpd.yml, etc.) that trigger on push to refactor. Consider disabling via `gh api -X PUT /repos/gretel/maia-sdr/actions/workflows/$ID/disable`.

## Other Notes

- **Fork**: `gretel/maia-sdr` (user: Tom Hensel). Upstream: `F5OEO/maia-sdr`. Remote: `fork` for push, `origin` for fetch-only.
- **External volume**: `/Volumes/MacroSmol/work/` — 95 GB free after cleanup. OrbStack VM disk at `/Volumes/MacroSmol/work/docker/data.img.raw` (200 GB allocated, 8 TB sparse max).
- **CWD**: `/Users/tom/src/uhd/maia-sdr`, branch `refactor`, latest commit `6dce4f5`.
- **Uploaded Vivado image**: 13 chunks (24 GB) at `https://github.com/gretel/maia-sdr/releases/tag/vivado-2025.2`. Load: `cat vivado-chunk-* | docker load`.
- **AGENTS.md** says no `sudo`/`su`, use `trash` not `rm -r`, no AI traces in commits, `prek run` pre-commit (no prek config in this repo).
- **Cron jobs may not fire** — rely on direct `gh run view` checks instead.
- Stale cron prompts for old run IDs: answer in <5 words, disengage.
