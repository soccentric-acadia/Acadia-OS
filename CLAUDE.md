# Acadia-OS — Yocto embedded Linux for Raspberry Pi 5

## Overview

Acadia-OS is the Yocto/OpenEmbedded build system for the **Acadia** platform —
the **Raspberry Pi 5 / CM4/CM5** (BCM2712 SoC + RP1 south-bridge) application
processor, with a **Pico W (RP2040)** as real-time co-processor. This is the
reference/baseline platform: nearly every other project's OS is described as a
port of Acadia-OS. Built with [kas](https://kas.readthedocs.io/) + Docker
against the `meta-raspberrypi` layer set, with A/B OTA updates via
[swupdate](https://sbabic.github.io/swupdate/).

## Quick Start

```bash
make kas-image        # Build the KAS Docker image (once)
make image rpi5       # Build the Yocto image for Raspberry Pi 5
```

## Build Targets

```
make image  rpi5        Build Yocto SD card image (RPi5)
make build  rpi5        Alias for image
make rebuild-image rpi5 cleansstate image recipe, then rebuild
make sdk    rpi5        Cross-toolchain SDK installer → deploy/sdk/
make esdk   rpi5        Extensible SDK installer     → deploy/esdk/
make shell  rpi5        Interactive kas shell
make swu                 Build .swu OTA package
make flash  rpi5 DEVICE=/dev/sdX   Flash image to SD card
```

## Boot Flow (RPi 5)

```
SD/eMMC → RPi firmware (config.txt) → U-Boot → kernel_2712.img
        → Linux → systemd → Acadia-HAL, Acadia services
```

## A/B OTA Layout

Partition table (`meta/meta-acadia/wic/sdimage-rpi5.wks`):
```
  p1  /boot   FAT32   kernel, DTBs, config.txt, cmdline.txt
  p2  /       rootfs-a (active after initial flash)
  p3  standby rootfs-b (updated by swupdate, then activated)
  p4  /home   persistent, grown on first boot by rpi5-home-init
```

`make swu` builds an `.swu` package. Signing via
`scripts/generate-swu-keys.sh` (RSA-4096).

## Layer Structure

| Layer               | Source                             | Purpose                              |
|---------------------|------------------------------------|--------------------------------------|
| `poky`              | poky (scarthgap)                   | OE core                              |
| `meta-oe`           | meta-openembedded (scarthgap)      | Package set                          |
| `meta-raspberrypi`  | meta-raspberrypi                   | RPi BSP, kernel, U-Boot              |
| `meta-swupdate`     | sbabic/meta-swupdate (scarthgap)   | swupdate OTA framework               |
| `meta-acadia`       | SiliconCentric/meta-acadia (local, in `meta/`) | Acadia image, HAL, swu config |

## Repo Notes

- `build/`, `cache/`, `sstate-cache/`, `layers/` are gitignored bind-mounted
  host dirs.
- `meta/meta-acadia` is committed **locally** in this repo (see `.gitignore`);
  upstream layers are cloned by kas into `layers/` and must never be
  hand-edited.
- Acadia is the **baseline** for the fleet — other platforms (Zion/Joshua/
  Pinnacle/Sequoia) are documented as ports of this repo.
