# Acadia-OS Build and Deployment

## Scope

Acadia-OS is the Raspberry Pi Yocto/KAS image-integration repository. The root Makefile builds
`acadia-image` for a selected board, emits WIC/SDK/eSDK artifacts, creates signed SWUpdate
bundles for supported A/B boards, validates metadata, and can flash an SD card.

## 1. Prerequisites

- Linux with GNU Make, Docker, `curl`, OpenSSL, `cpio`, `bmaptool`, and sufficient disk space
for Yocto downloads, sstate, and build output.
- Docker running; KAS version defaults to 4.5. `make kas-container-script` downloads the pinned
helper from the KAS release URL.
- Network access for layers and source downloads, plus access to any private layers or SSH
material required by the KAS configuration.
- A board configuration under `kas/boards/<BOARD>.yaml`. Default `BOARD` is `rpi5`; supported
names are listed in the Makefile.
- For production OTA, the private key at `meta/meta-acadia/swupdate/keys/swupdate-private.pem`.
Keep it out of source control and protect it as a deployment secret.

## 2. Setup

```sh
make test
make kas-container-script
make ensure-image
make check-board
```

KAS uses `kas/common.yaml`, the board YAML, Poky, meta-openembedded, meta-raspberrypi,
meta-swupdate, and meta-acadia. Build/download/sstate directories default to `build/` and
`cache/{downloads,sstate-cache}` and can be overridden with `BUILD_DIR`, `DL_DIR`, and
`SSTATE_DIR`.

## 3. Build and compile

```sh
make build rpi5
make image rpi4-64
make rebuild-image rpi5
make shell rpi5
make validate rpi5
make lint
```

`build` and `image` run KAS and automatically stage WIC artifacts under
`deploy/images/<BOARD>_<timestamp>/`. `rebuild-image` cleans the selected image recipe's sstate
before rebuilding. `validate` performs board/config and BitBake parse/feature checks and is
conditional on the KAS Docker image. `lint` includes Makefile, YAML, SWUpdate-copy
synchronization, and reproducibility checks; its YAML stage runs inside the KAS image.

## 4. Test and lint

```sh
make test
make check-board
make lint
make validate rpi5
```

`test` checks host Docker and curl. It is a prerequisite check, not a Yocto runtime test. `lint`
and `validate` inspect metadata; boot, drivers, OTA rollback, and application behavior require
hardware verification.

## 5. Packaging and artifacts

```sh
make sdk rpi5
make esdk rpi5
make sdk-image rpi5
make esdk-image rpi5
make swu rpi5 SWU_VERSION=1.2.3
```

SDK installers are copied to `deploy/sdk/<BOARD>_<timestamp>/`; eSDK installers go to
`deploy/esdk/<BOARD>_<timestamp>/`; WIC/WIC.BMAP images go to
`deploy/images/<BOARD>_<timestamp>/`; SWU bundles go to `deploy/swu/<BOARD>_<timestamp>/` and
are also created as `build/<BOARD>-<SWU_VERSION>.swu`. `sdk-image` and `esdk-image` additionally
build Docker images named `<BOARD>-sdk:latest` and `<BOARD>-esdk:latest` by default.

**Deploy retention (task 012):** each successful `deploy-images`, `deploy-sdk` or `deploy-esdk`
run prunes its own type directory afterwards, keeping only the newest `DEPLOY_KEEP ?= 1`
snapshots per board — by default exactly the snapshot that was just written. Pruning never
touches other boards' snapshots, `deploy/swu/`, or the snapshot just written, and runs only
after the copy (and, for images, the SHA-256 manifest) succeeded. Set `DEPLOY_KEEP=<n>` to keep
a short history. Consumers are unaffected: they always select the newest copy
(`validation/tools/generate-manifest.sh` and CI both use `ls -td … | head -1`).

## 6. Deployment, install, and run

```sh
make flash rpi5 DEVICE=/dev/sdX
```

`flash` is destructive and conditional: `DEVICE` must be a real block device, the correct
`.wic.bz2` and `.bmap` must exist, and the operator must positively identify the removable
media. For OTA, `make swu` supports only `rpi5` and `cm5`, requires kernel/DTB matches, and
signs with RSA-4096 when the private key is present. `SWU_ALLOW_UNSIGNED=1` creates a
development-only bundle that the target is expected to reject. There is no cloud deployment
target.

## 7. Cleanup

```sh
make clean
make clean-build
make clean-docker
make clean-all
```

`clean`/`clean-build` remove `build/`; `clean-docker` removes KAS, SDK, and eSDK images;
`clean-all` also removes download and sstate caches. Cache removal is expensive and may require
redownloading all Yocto sources.

## 8. Hardware, cloud, and manual verification caveats

Board selection controls `MACHINE`, kernel/DTB names, overlays, GPU memory, UART, U-Boot, A/B
layout, and image contents. Validate the exact board, boot media, power, serial console,
network, first boot, partition expansion, OTA install, signature verification, rollback, and
recovery on physical hardware. The build can pass while firmware, proprietary license flags,
device-tree overlays, storage, or peripherals are wrong. Never expose signing keys or treat
development credentials as production deployment inputs.
