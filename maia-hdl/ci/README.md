# maia-hdl CI build

Docker-based Vivado 2025.2 bitstream builds for GitHub Actions.

## Files

| File | Purpose |
|------|---------|
| `build.ci.tcl` | In-process synth/impl script |
| `install_config.txt` | Vivado ML Standard installer config (Zynq-7000 + common 7-series) |
| `vivado-image.dockerfile` | Docker image definition for the Vivado container |

## How it works

The CI workflow (`../../.github/workflows/maia-hdl-bitstream.yml`) does:

1. **Download** pre-built Vivado Docker image from GitHub Releases (public)
2. **IP cores**: Python (Amaranth) generates Verilog, Vivado packages IPs
3. **Build**: `build.ci.tcl` runs synth/impl in-process:
   `synth_design → opt_design → place_design → route_design → write_bitstream`

## Setup: Build the Vivado Docker image

Required once per account. Needs the Vivado ML Standard 2025.2 installer (~96 GB tar).

```bash
# 1. Build the image
docker build --platform linux/amd64 -t xilinx-vivado:2025.2 -f vivado-image.dockerfile .

# 2. Save and split for GitHub Release (bypasses GHCR 10 GB layer limit)
docker save xilinx-vivado:2025.2 | split -b 1900m - vivado-chunk-

# 3. Upload to a GitHub Release on your repository
gh release create vivado-2025.2 --title "Vivado 2025.2 Docker Image" --notes "Load: cat vivado-chunk-* | docker load"
for chunk in vivado-chunk-*; do
  gh release upload vivado-2025.2 "$chunk" --clobber
done

# 4. Update the workflow env vars:
#    RELEASE_REPO: your-org/your-repo
#    RELEASE_TAG: vivado-2025.2
```

## Local testing

```bash
docker run --platform linux/amd64 --rm -it \
  -v $(pwd):/work:rw \
  xilinx-vivado:2025.2 \
  /bin/bash -c "source /opt/Xilinx/2025.2/Vivado/settings64.sh && bash"

# Inside container:
cd /work/maia-hdl/ip && make
cd /work/maia-hdl/projects
PROJECT_NAME=pluto vivado -mode batch -source ../ci/build.ci.tcl
```
