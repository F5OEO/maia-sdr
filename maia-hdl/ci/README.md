# maia-hdl CI build

Docker-based Vivado 2025.2 bitstream builds for GitHub Actions.

## Files

| File | Purpose |
|------|---------|
| `build.ci.tcl` | In-process synth/impl script (avoids `launch_runs` crash under Rosetta) |
| `install_config.txt` | Vivado ML Standard installer config (Zynq-7000 + common 7-series) |

## How it works

The CI workflow (`../../.github/workflows/maia-hdl-bitstream.yml`) does:

1. **Pull** `ghcr.io/maia-sdr/maia-sdr/vivado:2025.2` (pre-built Docker image)
2. **IP cores**: Python (Amaranth) generates Verilog, Vivado packages IPs
3. **Build**: `build.ci.tcl` sources each project's `system_project.tcl` with
   `ADI_SKIP_SYNTHESIS=1` (skips `launch_runs`), then runs in-process:
   `synth_design → opt_design → place_design → route_design → write_bitstream`

## Setup: Build & push the Vivado Docker image

Required once. Needs the Vivado ML Standard 2025.2 installer (~96 GB tar).

```bash
# 1. Clone filmil/vivado-docker
git clone https://github.com/filmil/vivado-docker.git
cd vivado-docker

# 2. Copy installer tarball + config
cp /path/to/FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157_1.tar .
cp /path/to/maia-hdl/ci/install_config.txt .

# 3. Build image (~90 min)
make HOST_TOOL_ARCHIVE_NAME=FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157_1.tar build

# 4. Tag & push to GHCR
docker tag xilinx-vivado:2025.2 ghcr.io/maia-sdr/maia-sdr/vivado:2025.2
docker push ghcr.io/maia-sdr/maia-sdr/vivado:2025.2
```

### Rosetta workaround (Apple Silicon)

The filmil Docker image includes `/opt/udev_stub.so` to work around a libudev
crash under Rosetta. The `build.ci.tcl` script uses in-process TCL commands
instead of `launch_runs` to avoid child-process crashes.

## Local testing

```bash
# Run the Vivado container with the project mounted
docker run --platform linux/amd64 --rm -it \
  -v $(pwd):/src:rw \
  -v /tmp/vivado-output:/work:rw \
  -e XILINX_LOCAL_USER_DATA=no \
  -e LD_PRELOAD=/opt/udev_stub.so \
  ghcr.io/maia-sdr/maia-sdr/vivado:2025.2 \
  /bin/bash -c "source /opt/Xilinx/2025.2/Vivado/settings64.sh && bash"

# Inside container:
cd /src/maia-hdl/ip && make
cd /src/maia-hdl/projects
PROJECT_NAME=pluto vivado -mode batch -source ../ci/build.ci.tcl
```
