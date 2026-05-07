# Raspberry Pi 5 — Yocto / KAS Build

A fully reproducible, Docker-based Yocto build for the **Raspberry Pi 5** using
[KAS](https://kas.readthedocs.io/) as the configuration and fetch manager.
The resulting SD card image expands automatically to fill the entire card on
first boot — no manual resizing needed.

---

## Features

- **Yocto Scarthgap (LTS)** — stable, long-term-support release
- **KAS** — single YAML file pins every layer, branch, and local-conf setting
- **Docker build environment** — zero host-pollution, fully reproducible
- **`core-image-base`** target — lean, production-ready base image
- **Custom WKS** — tight SD card layout (256 MB FAT boot + ext4 root)
- **Auto-expand on first boot** — systemd one-shot grows the root partition and
  filesystem to consume all available SD card space
- **bmaptool flashing** — fast, verified SD card writes via `.bmap` sparse maps
- **Shared sstate/download cache** — subsequent builds are dramatically faster

---

## Repository Layout

```
rpi/
├── Makefile                            # Top-level build entry point
├── kas/
│   ├── base.yaml                       # Shared layers, repos, and local.conf
│   └── rpi5.yaml                       # RPi5 machine config (includes base.yaml)
├── docker/
│   ├── Dockerfile                      # KAS image + bmap-tools + extras
│   └── Makefile                        # Builds the Docker image
├── meta/
│   └── meta-custom/                    # Project-local Yocto layer
    ├── conf/layer.conf
    ├── wic/
    │   └── sdimage-rpi5.wks            # SD card partition layout
    ├── recipes-core/images/
    │   └── core-image-base.bbappend    # Adds expand-rootfs to image
    └── recipes-support/expand-rootfs/
        ├── expand-rootfs.bb
        └── files/
            ├── expand-rootfs.sh        # parted + resize2fs one-shot script
            └── expand-rootfs.service
```

---

## Requirements

| Tool | Minimum version | Notes |
|---|---|---|
| Docker | 20.10+ | Engine or Desktop, `buildx` not required |
| GNU Make | 4.0+ | Available on all Linux distros |
| bmaptool | any | For `make flash` — `apt install bmap-tools` |

No Yocto host dependencies (Python, BitBake, etc.) are needed — everything runs
inside the container.

---

## Quick Start

```bash
# 1. Clone the repository
git clone <your-repo-url> rpi && cd rpi

# 2. Build everything  (Docker image → kas-container → BitBake)
make

# 3. Flash to SD card
make flash DEVICE=/dev/sdX
```

On first run `make` downloads the `kas-container` script from the KAS project,
builds the custom Docker image, then delegates all BitBake work to
`kas-container build` — the standard KAS invocation.

---

## Make Targets

```
make [target] [OPTION=value ...]
```

| Target | Description |
|---|---|
| `build` *(default)* | Build the Docker image, then run `kas-container build` |
| `image` | Build (or rebuild) the KAS Docker image only |
| `shell` | `kas-container shell` — interactive BitBake environment |
| `flash DEVICE=/dev/sdX` | Flash the latest `.wic.bz2` image to an SD card |
| `clean` | Delete the `build/` directory |
| `clean-all` | Delete `build/`, `downloads/`, and `sstate-cache/` |
| `help` | Print a concise option/target reference |

### Overridable variables

| Variable | Default | Description |
|---|---|---|
| `KAS_IMAGE` | `rpi5-kas:latest` | Docker image name:tag used for builds |
| `BUILD_DIR` | `./build` | Yocto build output directory |
| `DL_DIR` | `./downloads` | Download cache (bind-mounted into container) |
| `SSTATE_DIR` | `./sstate-cache` | Shared state cache (bind-mounted) |

Example — use a pre-existing shared cache on a build server:

```bash
make DL_DIR=/srv/yocto/downloads SSTATE_DIR=/srv/yocto/sstate
```

---

## KAS Configuration

A single file — `kas/rpi5.yaml` — defines everything: machine, distro, all
layer repos, and `local.conf` settings. All external layers are cloned under
`meta/` by KAS at build time, keeping the project root clean.

KAS fetches and configures the following layers:

| Layer | Branch | Purpose |
|---|---|---|
| `poky` | scarthgap | Core OE build system + distro |
| `meta-openembedded` | scarthgap | Extra packages (oe, python, networking, multimedia) |
| `meta-raspberrypi` | scarthgap | RPi BSP, firmware, kernel config |
| `meta-custom` | *(local)* | WKS layout + auto-expand recipe |

Key `local.conf` settings (defined in `kas/rpi5.yaml`):

```
MACHINE        = "raspberrypi5"
INIT_MANAGER   = "systemd"
IMAGE_FSTYPES  = "wic.bz2 wic.bmap"
WKS_FILE       = "sdimage-rpi5.wks"
ENABLE_UART    = "1"
GPU_MEM        = "128"
```

---

## SD Card Layout & Auto-Expand

### Partition layout (written by BitBake / `wic`)

| Partition | Type | Size | Mount | Contents |
|---|---|---|---|---|
| `mmcblk0p1` | FAT32 | 256 MB | `/boot` | kernel, DTBs, overlays, `config.txt` |
| `mmcblk0p2` | ext4 | rootfs content + tiny margin | `/` | OS, applications |

The rootfs partition is intentionally written small (just enough for the image
content). On **first boot** the `expand-rootfs.service` systemd unit:

1. Runs `parted resizepart` to grow the partition entry to 100% of the disk
2. Runs `resize2fs` to expand the live ext4 filesystem into the new space
3. Writes `/var/lib/expand-rootfs-done` so the operation never repeats

This means a 4 GB image flashed to a 64 GB card will, after one reboot, have
~63 GB of usable root space.

---

## Flashing the SD Card

```bash
# Using the Makefile (recommended — uses bmaptool for fast verified writes)
make flash DEVICE=/dev/sdb

# Manual bmaptool
IMAGE=$(ls build/tmp/deploy/images/raspberrypi5/*.wic.bz2 | tail -1)
BMAP=${IMAGE%.bz2}.bmap
sudo bmaptool copy --bmap "$BMAP" "$IMAGE" /dev/sdb

# Manual dd fallback (slower, no verification)
bzcat "$IMAGE" | sudo dd of=/dev/sdb bs=4M conv=fsync status=progress
```

> **Warning** — double-check `DEVICE`. Writing to the wrong device will
> destroy data. Use `lsblk` to identify your SD card.

---

## Iterative Development

```bash
# Drop into a kas-managed interactive shell
make shell

# Inside the container:
bitbake core-image-base        # full image build
bitbake -c devshell <recipe>   # debug a specific recipe
bitbake -c cleansstate <recipe> && bitbake <recipe>   # force rebuild
```

---

## Customising the Image

### Adding packages

Edit [meta/meta-custom/recipes-core/images/core-image-full-cmdline.bbappend](meta/meta-custom/recipes-core/images/core-image-full-cmdline.bbappend):

```bitbake
IMAGE_INSTALL:append = " htop nano python3 openssh"
```

### Adding a new recipe

Drop a `.bb` file under `meta-custom/recipes-<category>/<name>/` —
the layer's `BBFILES` glob will pick it up automatically.

### Changing the kernel config

Add a `linux-raspberrypi_%.bbappend` with a `SRC_URI` fragment:

```bitbake
# meta-custom/recipes-kernel/linux/linux-raspberrypi_%.bbappend
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " file://my-fragment.cfg"
```

### Hardware overlays / `config.txt`

`meta-raspberrypi` exposes `RPI_EXTRA_CONFIG` for appending lines to
`config.txt` from `local.conf` or a bbappend:

```bitbake
RPI_EXTRA_CONFIG:append = '\ndtoverlay=w1-gpio\n'
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `ERROR: No space left on device` during build | Mount a larger `BUILD_DIR` or free disk space; Yocto builds need ~50 GB |
| BitBake fetch fails behind a proxy | Pass `-e http_proxy=… https_proxy=…` to the `docker run` in the Makefile |
| `bmaptool: command not found` | `sudo apt install bmap-tools` on the host |
| Boot hangs at rainbow screen | Re-flash; the image may be corrupt |
| Root partition not expanding | Check `journalctl -u expand-rootfs` on the target |
| `LICENSE_FLAGS_ACCEPTED` warning | Already handled in `kas/rpi5.yaml`; update the value if a new firmware is added |

---

## Licence

All files in this repository are released under the **MIT Licence** unless
otherwise noted. Third-party Yocto layers retain their own licences.
