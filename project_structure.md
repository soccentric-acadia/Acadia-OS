# Yocto OS Project Structure

This document describes the Acadia-OS repository layout and provides a reusable project structure for future containerized Yocto/OpenEmbedded operating-system projects.

## Repository Layout

```text
project-root/
├── Makefile                         # Build, SDK, OTA, flash, deploy, clean, and validation commands
├── README.md                        # Quick start, supported boards, and operator documentation
├── project_structure.md             # This project layout reference
├── CLAUDE.md                        # Repository-specific engineering guidance and lessons learned
├── feature.txt                      # Product feature checklist
├── acadia.sh                         # BitBake/build convenience wrapper
├── kas-container                     # KAS container helper script
├── rpi-make-completion.bash          # Bash completion for Make targets and boards
│
├── kas/
│   ├── common.yaml                   # Shared repositories, layers, and Yocto configuration
│   ├── boards/                       # One board configuration per supported machine
│   │   ├── rpi5.yaml
│   │   ├── rpi4-64.yaml
│   │   └── <additional-board>.yaml
│   └── repos/                        # Pinned external layer repository definitions
│       ├── poky.yaml
│       ├── meta-openembedded.yaml
│       ├── meta-raspberrypi.yaml
│       ├── meta-swupdate.yaml
│       └── meta-acadia.yaml
│
├── meta/
│   └── meta-acadia/                  # Project-specific Yocto layer
│       ├── conf/layer.conf           # Layer registration and recipe discovery
│       ├── recipes-core/
│       │   ├── images/               # Canonical product image recipes
│       │   ├── packagegroups/        # Reusable package collections
│       │   ├── acadia-services/      # Product systemd services
│       │   └── os-release/           # OS identification metadata
│       ├── recipes-bsp/              # Bootloader, firmware, and board support
│       ├── recipes-connectivity/    # Ethernet, Wi-Fi, Bluetooth, and cloud setup
│       ├── recipes-kernel/           # Kernel pins, fragments, patches, and overlays
│       ├── recipes-support/          # First-boot, storage, and diagnostic services
│       ├── recipes-swupdate/         # Target-side SWUpdate configuration and health checks
│       ├── swupdate/                 # SWUpdate manifest, hooks, and signing material
│       └── wic/                      # WIC partition layouts
│
├── docker/
│   ├── yocto/                        # KAS/BitBake build container
│   ├── sdk/                          # Standard SDK container and staged installer
│   └── esdk/                         # Extensible SDK container and staged installer
│
├── scripts/
│   ├── generate-swu-keys.sh          # Generate OTA signing keys
│   ├── pin-layers.sh                 # Pin external layer revisions
│   ├── validate-yaml.py              # Validate KAS YAML syntax
│   └── tests/                        # Bats regression tests
│
├── .github/workflows/                # CI build and validation workflows
├── build/                             # Generated Yocto build directory; do not commit
├── downloads/                        # Shared source download cache; do not commit
├── sstate-cache/                      # Shared BitBake state cache; do not commit
├── layers/                            # KAS checkout directory; do not commit
└── deploy/                            # Board/timestamped output artifacts; do not commit
```

## Directory Responsibilities

### Root `Makefile`

The Makefile is the stable developer interface. It should provide:

- `image` or `build`
- `rebuild-image`
- `sdk` and `esdk`
- `shell`
- `swu`
- `flash`
- `kas-image`, `sdk-image`, and `esdk-image`
- Artifact deployment targets
- `lint`, `test`, `validate`, and `check-board`
- `clean`, `clean-build`, `clean-docker`, and `clean-all`
- `help` and shell completion

Keep board selection, image target, cache paths, Docker image names, and OTA version configurable through Make variables.

### `kas/`

KAS configuration controls repository checkout, layer composition, machine selection, and shared BitBake configuration.

`common.yaml` should contain only values shared by every board. Each board file should contain a valid `machine:` field and only the overrides required for that board.

Pin every external repository to a full 40-character commit SHA. Do not use `HEAD`, `AUTOREV`, floating tags, or unpinned release branches for production builds.

### `meta/meta-<project>/`

The project layer contains all product-specific Yocto metadata. Rename `meta-acadia` to `meta-<project>` when starting a new OS project.

Use one canonical image recipe. Put reusable package sets in package groups rather than duplicating long `IMAGE_INSTALL` lists across several images.

Recommended recipe ownership:

| Directory | Use |
|---|---|
| `recipes-core/images` | Product image policy and image contents |
| `recipes-core/packagegroups` | Runtime, middleware, cloud, diagnostics, and development package sets |
| `recipes-bsp` | Bootloader and firmware configuration |
| `recipes-connectivity` | Ethernet, Wi-Fi, Bluetooth, network services, and cloud transport |
| `recipes-kernel` | Kernel version, configuration fragments, patches, and device trees |
| `recipes-support` | First-boot setup, storage initialization, health services, and diagnostics |
| `recipes-swupdate` | Installed SWUpdate daemon configuration and boot health checks |
| `swupdate` | `.swu` manifest and install hooks assembled by the host build |
| `wic` | Board-specific boot, rootfs, recovery, and persistent-data partitions |

### `docker/`

All Yocto and SDK operations should run inside containers:

- `docker/yocto/`: KAS and BitBake build environment
- `docker/sdk/`: standard cross-toolchain image
- `docker/esdk/`: extensible SDK and `devtool` image

The SDK Docker build context should receive a generated installer from the Yocto build. Do not commit real generated SDK installers unless the project explicitly requires them.

### `swupdate/` and OTA

The OTA design should define these boundaries clearly:

- `sw-description`: package contents, version, hardware compatibility, and handlers
- `pre-install.sh`: identify and prepare the inactive slot
- `post-install.sh`: update boot selection and persist the new slot
- Boot-check service: verify kernel, device tree, root filesystem, and application health
- Bootloader: provide retry limits and automatic rollback

Use partition labels, PARTUUIDs, or filesystem UUIDs instead of hardcoded device paths. Keep private signing keys outside Git and commit only the public verification key.

### `wic/`

The WIC file must agree with:

- The selected Yocto machine
- Bootloader configuration
- Kernel command line
- SWUpdate inactive-slot selection
- Persistent data requirements
- Recovery and rollback behavior

For A/B systems, document boot, rootfs-A, rootfs-B, and persistent-data partitions explicitly.

## Reusable Project Template

For a new Yocto OS project, copy this structure and replace project-specific names:

```text
new-project/
├── Makefile
├── README.md
├── project_structure.md
├── kas/
│   ├── common.yaml
│   ├── boards/<board>.yaml
│   └── repos/<layer>.yaml
├── meta/meta-<project>/
│   ├── conf/layer.conf
│   ├── recipes-core/images/<project>-image.bb
│   ├── recipes-core/packagegroups/packagegroup-<project>-base.bb
│   ├── recipes-bsp/<bootloader-or-firmware>/
│   ├── recipes-connectivity/<networking>/
│   ├── recipes-kernel/linux/linux-%.bbappend
│   ├── recipes-support/<firstboot-or-service>/
│   ├── recipes-swupdate/<swupdate-config>/
│   ├── swupdate/sw-description
│   └── wic/<board>.wks
├── docker/yocto/Dockerfile
├── docker/sdk/Dockerfile
├── docker/esdk/Dockerfile
├── scripts/validate-yaml.py
├── scripts/generate-swu-keys.sh
└── tests/
```

## New Project Checklist

1. Rename the project layer to `meta-<project>`.
2. Select one canonical image recipe named `<project>-image.bb`.
3. Add pinned Poky, BSP, and optional layer repositories.
4. Add one KAS board file per supported machine.
5. Define the WIC partition layout.
6. Add kernel and bootloader configuration.
7. Add connectivity and first-boot services.
8. Decide whether OTA is single-slot, A/B, or recovery-based.
9. Implement inactive-slot detection using persistent identifiers.
10. Add boot health checks and rollback limits before enabling production OTA.
11. Generate signing keys securely and keep private keys out of Git.
12. Configure SDK and eSDK output paths.
13. Add static tests for board files, Make targets, recipes, and OTA manifest consistency.
14. Run validation before a full build:

```bash
make test
make lint
make check-board
make validate
```

15. Run a containerized metadata parse:

```bash
make shell <board>
bitbake -p <project>-image
```

16. Perform a complete image build and test the image on every supported board before production use.

## Generated Directories

These directories are build outputs and should remain ignored by Git:

- `build/`: BitBake work directory and deploy output
- `downloads/`: downloaded source archives and Git mirrors
- `sstate-cache/`: shared BitBake task cache
- `layers/`: KAS-managed external layer checkouts
- `deploy/`: copied images, SDKs, eSDKs, and SWUpdate bundles

Keeping generated data outside version control makes the project portable, reproducible, and suitable for CI runners.
