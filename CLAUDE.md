# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Acadia OS** — A fully containerised Yocto/OpenEmbedded build system for the entire Raspberry Pi family (RPi 1 through RPi 5, Compute Modules 1-5). Every build runs inside a Docker container via [kas](https://kas.readthedocs.io), so the host machine never needs Yocto dependencies installed.

Key features:
- One `make` command builds a flashable SD card image
- A/B OTA updates via SWUpdate with built-in web UI (RPi 5 / CM5)
- Systemd init with DHCP Ethernet, Wi-Fi, and Bluetooth out of the box
- gRPC + Protobuf (C++ runtime, compiler, and Python bindings) pre-installed
- Persistent `/home` partition that survives OTA updates
- Standard and extensible SDK generation for cross-compilation
- Bash tab-completion for all `make` targets and board names

## Common Development Commands

### Build Commands
```bash
# Build SD card image for RPi 5 (default board)
make image rpi5

# Build for other boards
make image rpi4-64
make image rpi3-64
make image cm5

# Rebuild after adding packages (cleans sstate for image recipe)
make rebuild-image rpi5

# Interactive shell inside the build container
make shell rpi5
```

### SDK Commands
```bash
# Build cross-toolchain SDK installer (deployed to deploy/sdk/)
make sdk rpi5

# Build extensible SDK installer with devtool (deployed to deploy/esdk/)
make esdk rpi5

# Full chain: Yocto SDK build → stage installer → Docker image → deploy
make sdk-image rpi5
make esdk-image rpi5

# Only build Docker image if absent
make ensure-sdk-image
make ensure-esdk-image
```

### OTA Update Commands
```bash
# Build .swu OTA package (version = timestamp)
make swu rpi5

# Build .swu with explicit version
make swu rpi5 SWU_VERSION=1.2.3
```

### Flash Commands
```bash
# Flash SD card image to device
make flash rpi5 DEVICE=/dev/sdX
```

### Docker Image Commands
```bash
# Build/rebuild KAS Yocto build container
make kas-image

# Remove all Docker images (kas, sdk, esdk)
make clean-docker
```

### Clean Commands
```bash
# Remove build/ directory
make clean

# Remove build/, downloads/, and sstate-cache/
make clean-all
```

### Utility Commands
```bash
# Install bash tab-completion
make completion && source ~/.bashrc

# Show help
make help
```

## High-Level Architecture

### Repository Structure
```
Acadia-OS/
├── Makefile                    # Top-level build orchestration
├── kas-container               # kas helper script (auto-downloaded)
├── rpi-make-completion.bash    # Bash tab-completion script
├── acadia.sh                   # Simple bitbake wrapper
├── kas/
│   ├── common.yaml             # Shared baseline: repos, layers, local.conf defaults
│   ├── boards/                 # Per-board YAML files (include common.yaml)
│   │   ├── rpi5.yaml           # RPi 5 — A/B OTA WKS override
│   │   ├── cm5.yaml            # CM5 IO Board
│   │   └── ...                 # One file per supported board
│   └── repos/                  # External layer repo definitions
├── docker/
│   ├── yocto/                  # KAS Yocto build container
│   │   ├── Dockerfile          # Extends kas:latest with bmap-tools, fdisk, etc.
│   │   └── Makefile
│   ├── sdk/                    # Standard SDK Docker image
│   │   ├── Dockerfile          # Ubuntu 22.04 + cross-toolchain SDK
│   │   ├── Makefile
│   │   └── sdk.sh              # SDK installer (staged by 'make sdk-image')
│   └── esdk/                   # Extensible SDK Docker image
│       ├── Dockerfile          # Ubuntu 22.04 + eSDK + devtool
│       ├── Makefile
│       └── esdk.sh             # eSDK installer (staged by 'make esdk-image')
├── meta/
│   └── meta-acadia/            # Project-specific Yocto layer
│       ├── conf/layer.conf
│       ├── recipes-core/
│       │   ├── images/core-image-full-cmdline.bbappend  # Image customisation
│       │   ├── rpi5-home-init/  # Persistent /home first-boot init
│       │   ├── acadia-services/ # Systemd services
│       │   ├── acadia-data-init/ # Data partition init
│       │   └── os-release/      # OS release info
│       ├── recipes-connectivity/
│       │   ├── rpi5-connectivity/  # systemd-networkd, wpa_supplicant, Bluetooth
│       │   ├── openssh/            # SSH config
│       │   └── acadia-client/      # Client (excluded until upstream exists)
│       ├── recipes-kernel/
│       │   └── linux/linux-raspberrypi_6.6.bbappend  # Kernel pin + nobranch fix
│       ├── recipes-support/
│       │   └── expand-rootfs/  # First-boot partition expansion
│       ├── recipes-swupdate/
│       │   └── rpi5-swupdate-config/  # SWUpdate daemon config + boot-check
│       ├── recipes-bsp/
│       │   └── u-boot/         # U-Boot configuration for A/B OTA
│       ├── swupdate/           # SWUpdate description, scripts, keys
│       └── wic/
│           └── sdimage-rpi5.wks  # A/B OTA partition layout
├── layers/                     # Cloned by kas (not committed)
│   ├── poky/
│   ├── meta-openembedded/
│   ├── meta-raspberrypi/
│   └── meta-swupdate/
├── build/                      # BitBake build directory (not committed)
├── downloads/                  # Source tarballs shared across builds
└── sstate-cache/               # Shared state cache
```

### KAS Configuration

**`kas/common.yaml`** — Shared baseline:
- Defines all external layer repos (pinned to `scarthgap` / Yocto 5.0 LTS)
- Common `local.conf` settings applied to every board:
  - `INIT_MANAGER = "systemd"`
  - `IMAGE_FSTYPES = "wic.bz2 wic.bmap ext4"`
  - `ENABLE_UART = "1"` / `GPU_MEM = "128"`
  - Proprietary firmware licence acceptance
  - Shared `DL_DIR` / `SSTATE_DIR` paths (bind-mounted by container)
  - `CONF_VERSION = "2"` (required by Poky sanity checks)
  - U-Boot configuration for A/B OTA (RPi 5 / CM5)

**`kas/boards/<BOARD>.yaml`** — Per-board overrides:
- Each file includes `common.yaml` via `header.includes`
- Sets the `machine:` field
- Boards needing non-default `WKS_FILE` (rpi5, cm5) add `local_conf_header` override

### Image Contents (from `meta-acadia/recipes-core/images/core-image-full-cmdline.bbappend`)

- **Connectivity**: Ethernet DHCP (systemd-networkd), Wi-Fi (wpa_supplicant), Bluetooth (bluez5)
- **OTA**: SWUpdate daemon with Mongoose web server on port 8080, boot-check service
- **gRPC + Protobuf**: protobuf, protobuf-lite, grpc, python3-grpcio, python3-protobuf
- **Hardware interfaces**: I2C, SPI, GPIO, UART, USB, PCI/NVMe, CAN bus tools
- **System tools**: lshw, ethtool, devmem2, cpupower, watchdog, sysstat, iotop, strace, v4l-utils, vim
- **Acadia services**: acadia-hal, acadia-services
- **User**: `rpi` (locked, SSH key access only, member of sudo group)

### Partition Layout (RPi 5 / CM5)

Custom WKS file (`meta-acadia/wic/sdimage-rpi5.wks`) creates four-partition A/B layout:
```
p1  /boot      256 MB   FAT32   kernel, DTBs, config.txt
p2  /          8192 MB  ext4    rootfs-a  ← active slot
p3  (none)     8192 MB  ext4    rootfs-b  ← standby slot
p4  /home      512 MB*  ext4    persistent home (expands on first boot)
```

### OTA Update Flow (SWUpdate)

1. **pre-install.sh** — Detects active slot, creates `/dev/swupdate-inactive` symlink to other slot
2. SWUpdate `raw` handler streams `rootfs.ext4.gz` onto inactive partition
3. **post-install.sh** — Resolves PARTUUID of new partition, patches `root=PARTUUID=...` in `/boot/cmdline.txt`
4. SWUpdate triggers reboot; RPi firmware boots new slot
5. **swupdate-bootcheck.service** — Confirms healthy boot, marks slot permanent

### First-Boot Services

- **rpi5-home-init.service** — Creates `/home/rpi` with correct ownership on empty home partition, disables itself
- **expand-rootfs.service** — Grows root partition to fill SD card using `parted` + `resize2fs`, disables itself

## Key Files to Know

| File | Purpose |
|------|---------|
| `Makefile` | All build orchestration, board selection, Docker image management |
| `kas/common.yaml` | Shared KAS config: repos, layers, local.conf defaults |
| `kas/boards/*.yaml` | Per-board machine selection and WKS overrides |
| `meta/meta-acadia/recipes-core/images/core-image-full-cmdline.bbappend` | Image package selection and user config |
| `meta/meta-acadia/wic/sdimage-rpi5.wks` | A/B OTA partition layout |
| `meta/meta-acadia/swupdate/` | SWUpdate description, pre/post-install scripts, keys |
| `docker/yocto/Dockerfile` | Build container definition |
| `kas-container` | Wrapper script for running kas in Docker |

## Adding a New Board

1. Create `kas/boards/my-board.yaml`:
```yaml
header:
  version: 14
  includes:
    - common.yaml

machine: my-machine-name
```

2. Run `make build my-board`

## Customising the Image

### Adding Packages
Edit `meta/meta-acadia/recipes-core/images/core-image-full-cmdline.bbappend`:
```bitbake
IMAGE_INSTALL:append = " my-package another-package"
```
Then run `make rebuild-image rpi5`

### Adding a New Recipe
Place under `meta/meta-acadia/recipes-<category>/<name>/<name>.bb`. Layer's `conf/layer.conf` auto-discovers all `recipes-*/*/*.bb` files.

### Configuring Wi-Fi Credentials
After flashing, mount root partition and edit `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf`, or build credentials into the image by modifying `recipes-connectivity/rpi5-connectivity/files/wpa_supplicant-wlan0.conf`.

### Pinning/Updating Kernel
Edit `meta/meta-acadia/recipes-kernel/linux/linux-raspberrypi_6.6.bbappend` and update `SRCREV_machine`.

### Changing Poky/Layer Branch
All external layers pinned to **scarthgap** in `kas/common.yaml`. Update `branch:` and `commit:` fields there and re-run `make build`.

## CI/CD

GitHub Actions workflow (`.github/workflows/build.yml`):
- Triggers on push/PR to `main` and `scarthgap` branches
- Builds for `rpi5` board
- Caches Docker image, sstate, and downloads
- Uploads SD card image artifacts on success
- Uploads build logs on failure

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Docker | 20.10+ |
| GNU Make | 4.0+ |
| curl | any recent |
| bmaptool | for `make flash` |

No Yocto host dependencies (Python, BitBake, etc.) required — everything runs inside the container.

## Troubleshooting Tips

- **Speed up rebuilds**: Shared `DL_DIR` and `SSTATE_DIR` across all board builds
- **Interactive BitBake shell**: `make shell rpi4-64` then `bitbake core-image-full-cmdline`
- **Build logs**: `cat build/tmp/work/<arch>/<recipe>/<version>/temp/log.do_<task>.*`
- **CONF_VERSION mismatch**: Ensure `CONF_VERSION = "2"` in `kas/common.yaml` (KAS regenerates `build/conf/local.conf` on every invocation)
- **kas shell syntax**: Use `kas-container shell kas/rpi5.yaml -c "bitbake my-recipe"` (not `--`)
- **Stale Docker images**: `make kas-image`, `make sdk-image rpi5`, `make esdk-image rpi5`, `make clean-docker`
- **Free disk space**: `make clean` (build/), `make clean-all` (build/, downloads/, sstate-cache/), `make clean-docker`

## C1 — A/B OTA Rollback: lessons learned (2026-06-09)

**Do**
- **Trust the `RDEPENDS` chain for tool binaries.** `libubootenv` ships
  `fw_setenv`/`fw_printenv` to `${bindir}` (typically `/usr/bin/`) via
  GNUInstallDirs — *not* to `/usr/sbin`. Don't hardcode `/usr/sbin/fw_setenv`
  in scripts or `ConditionPathExists=` in unit files; resolve with
  `command -v` (or list both canonical paths with `ConditionPathExists=|…`).
- **Two copies of `post-install.sh` exist, only one ships in the .swu.**
  `meta/meta-acadia/swupdate/post-install.sh` is bundled into the SWUpdate
  package (referenced by `data = "postinst"` in `sw-description`). The
  copy in `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/`
  is what gets installed to the device's `/usr/lib/swupdate/`. Whenever
  you change the post-install logic, edit **both** — drift here is how
  the rollback chain silently regresses.
- **U-Boot env is the firmware-level source of truth; `/boot/boot_state`
  is the userspace accelerator.** Keep both updated by `post-install.sh`
  (set `upgrade_available=1`, `bootcount=0`, `bootlimit=3`) and have
  `bootcount-reset.service` clear the U-Boot env on a healthy boot —
  only after `swupdate-bootcheck.service` has passed.
- **Promote kernel/DTB integrity checks out of warning logs.** A mismatch
  in `/proc/cmdline` vs. `/boot/cmdline.txt` is **proof** the new slot
  didn't boot, not a warning. Roll back immediately rather than burning
  a `tries_remaining` tick.

**Don't**
- **Don't gate rollback on a service that runs after the network is up.**
  `swupdate-bootcheck.service` must be `After=local-fs.target` and
  `Before=network.target` — anything later means a broken slot is
  exposed to the LAN before the rollback path runs.
- **Don't write a stub `boot.cmd` and rely on the env defaults.** The
  U-Boot env bootcount flow (RAUC-style `bootcount`/`bootlimit`/
  `altbootcmd`) only works if `boot.cmd` *initialises* the env on
  first boot and ticks `bootcount` on subsequent boots. A 4-line
  `boot.scr` that just calls `booti` silently disables the rollback
  chain regardless of what the userspace scripts say.
- **Don't `set -e` through `fw_setenv` calls without logging.** When
  the env is corrupt, the tool returns non-zero. Wrap each
  `fw_setenv` with `||` + a `logger` line so a rollback is *visible*
  in the journal, not just a missing confirmation. (Docker images)

## C2 — OS review lessons learned (2026-06-10, 48 issues filed)

**Do**
- **Use `lsblk` / `/sys/class/block/*/partition` to derive parent disk
  and partition number.** Regex-parsing `/dev/mmcblk0p2` works for SD,
  fails on `nvme0n1p2` and `sda1`. The pattern `lsblk -ndo PKNAME +
  cat /sys/class/block/.../partition` is portable across all block
  devices — and is what `rpi5-home-init.sh` already uses. `expand-rootfs.sh`
  should match.
- **Pin every external layer and git SRCREV to a 40-char SHA.** Three
  layer yamls (`poky`, `meta-openembedded`, `meta-swupdate`) still set
  `commit: HEAD`; `acadia-hal_git.bb` uses `SRCREV = "${AUTOREV}"`.
  HEAD-tracking breaks reproducibility (§1, ISO 26262). Replace with
  pinned SHAs; add `SOURCE_DATE_EPOCH` to `common.yaml` for
  bit-for-bit rebuilds.
- **One canonical image recipe per project.** `acadia-image.bb` and
  `core-image-full-cmdline.bbappend` are two images that overlap
  content but inherit from different Yocto base recipes (`core-image`
  vs `core-image-full-cmdline`). Delete one — `acadia-image.bb` is
  the project standard (Makefile + CI both target it). Convert the
  other to a bbappend to the first, or delete.
- **CMake-based recipes: add `install(TARGETS ...)` upstream
  (preferred) or via patch — never `do_install` shell `find | install`
  loops.** The shell loop is fragile (find's `-o` precedence is a
  footgun; one missing parenthesis drops half the headers), bypasses
  BitBake's QA, and forces INSANE_SKIP. The same applies to
  `tomlplusplus_3.4.0.bb`: rename to `_git.bb`, use
  `PV = "<ver>+git${SRCPV}"`, drop `ALLOW_EMPTY` + empty `FILES:${PN}`.
- **Set `LIC_FILES_CHKSUM` even for `LICENSE = "CLOSED"` recipes.**
  BitBake's QA flags this; the alternative (no checksum) silently
  ships the package when the LICENSE file is changed upstream. See
  the pattern in `tomlplusplus_3.4.0.bb:6` (good) vs.
  `acadia-hal_git.bb` (missing).
- **`swupdate-bootcheck.sh` size bounds are per-file, not per-loop.**
  Iterate the loop and apply bounds per file: kernel > 1 MB, DTB
  > 10 KB, both < 10 MB. The current `||` (OR) trips on every
  healthy DTB boot (60 KB) — a health check that always reports
  unhealthy is worse than no health check.
- **Use `lsblk -no LABEL` for slot detection, not `/dev/mmcblk0p[23]`
  hardcodes.** The WKS labels partitions `rootfs-a` / `rootfs-b`;
  the opposite label is the inactive slot. This unblocks NVMe
  (RPi 5 with NVMe HAT) and USB boot.
- **Persistent diagnostic data goes to the journal, not `/var/log/`.**
  `dmesg-capture.service` writes to `/var/log/dmesg.boot`, which
  lives on the volatile filesystem and is lost on every reboot.
  Pipe to `systemd-cat` instead — `Storage=persistent` keeps it
  across reboots (`journalctl -t dmesg-boot -b -1`).

**Don't**
- **Don't `set -e` with `source <config-file>`.** The config file
  is parsed as a shell script; any line that looks like a command
  (e.g. `confirmed=false` in `boot_state`) aborts the script under
  `set -euo pipefail`. Use a `while IFS='=' read` loop instead —
  it never evaluates values, only assigns them.
- **Don't gate boot-time reset on `network-online.target` or
  external service health.** `bootcount-reset.service` waits for
  the network and `acadia-client.service`; on a lab board with a
  dead uplink the reset never fires and U-Boot rolls back a healthy
  slot. Match `swupdate-bootcheck.service` ordering:
  `After=local-fs.target`, `Before=network.target`.
- **Don't use `install -o` / `install -g` in first-boot scripts.**
  Busybox's `install` silently ignores both flags; the result is
  `root:root` ownership and the user can't log in. Use
  `mkdir -m 0750` + `chown` explicitly. The same applies to
  `find -o` precedence in the recipe `do_install` — the `-o` binds
  to the *preceding* `-name`, so only the first pattern is matched.
- **Don't ship `pre-install.sh` with dead code.** The
  `/mnt/rootfs-inactive` mountpoint check is never reached — the
  inactive partition is referred to by the `/dev/swupdate-inactive`
  symlink, not by a mountpoint. Dead code drifts.
- **Don't use `user=git` in `SRC_URI` with `protocol=ssh`.** The
  combination `git://...;protocol=ssh;user=git` is contradictory
  (user=git is meaningful only for the git:// protocol). Pick
  one — HTTPS for CI, SSH for interactive dev.
- **Don't hardcode RPi 5 kernel/DTB names in `make swu`.** The
  targets `kernel_2712.img` and `bcm2712-rpi-5-b.dtb` are BCM2712
  (RPi 5 / CM5) only. RPi 4 uses `kernel_2711.img`,
  `bcm2711-rpi-4-b.dtb`; RPi 3 uses `kernel_2710.img`,
  `bcm2710-rpi-3-b.dtb`. Per-board: derive from `MACHINE` (see
  `kas/boards/*.yaml`) or expose `SWU_KERNEL` / `SWU_DTB` as
  overridable Make variables.
- **Don't commit dev workstation scratch files (`patch_health.py`,
  `/config` with one URL, audit markdown, planning textfiles).** The
  repo root is not a scratch pad. `gh issue list --state all`
  shows the issues; the markdown planning files duplicate them and
  will drift.
- **Don't put `core-image` and `core-image-full-cmdline` in the
  same project's images.** They are different base recipes with
  different IMAGE_FEATURES (full-cmdline adds bash, debug-tweaks,
  sshd-dropbear). Mixing them gives an image that builds but does
  not match the documented behaviour.
- **Don't trust the `meta-acadia` kas fetch — it has a typo
  ("Acaida") and silently falls back to the in-tree layer.** Either
  remove the kas entry and rely on the in-tree layer, or fix the
  URL. Verify with
  `grep -n 'Acaida' kas/repos/*.yaml meta/ -r 2>/dev/null` (no
  matches expected).
- **Don't ship a default SSH password or print credentials to
  `/dev/console`.** The web-UI auth init script currently prints
  the admin password to the serial console and the journal on
  first boot. Logged serial consoles capture the password
  permanently. Either fail-closed (no web UI until operator
  sets a credential) or reveal the password once on the tty,
  suppress in journal.
- **Don't use `ALLOW_EMPTY` + `FILES:${PN} = ""` to ship a
  "dev-only" package.** The convention in Yocto is a `-dev` split
  package; the empty `FILES` + `ALLOW_EMPTY` is hard to read
  and signals "broken" to the next contributor.

**Verification commands run during this review (2026-06-10)**
- `git ls-files | sort` — 78 tracked files reviewed.
- `gh auth status` — auth ok, scopes include `repo`, `write:packages`.
- `gh issue list --state all --limit 200` — 19 historical (CLOSED)
  + 48 new (OPEN) issues filed; all labelled `[OS]` + a §7 category.
- `gh label create` — 7 new labels added: `build`, `security`,
  `improvement`, `test`, `concurrency`, `perf`, `OS`.

**Build/Test commands (not yet validated — see Issue #60 for harness)**
- Build: `make image rpi5` (Kas container, ~2h cold, ~5m warm).
- SWU:   `make swu rpi5 SWU_VERSION=$(date +%Y%m%d%H%M)`.
- Flash: `make flash rpi5 DEVICE=/dev/sdX`.
- Shell: `make shell rpi5` then `bitbake acadia-image`.

## C3 — Issue #30 boot_state parser: lessons learned (2026-06-10)

**Do**
- **Treat the parser, not the test, as the source of truth.** The
  `while IFS='=' read -r key value; do case …` block in
  `swupdate-bootcheck.sh` and `boot-watchdog.sh` is the canonical
  parser. The inline copy in
  `tests/test_boot_state_parser.bats` is a regression test — if
  either side changes, the other must change in the same commit.
- **Anchor the read loop on `${key}` for matching, never on
  `${value}`.** A backtick in the value slot must round-trip as a
  string (test "backticks NOT executed") and not influence control
  flow.
- **`git rebase --onto` a forked develop back onto `origin/develop`
  immediately after every PR squash-merge.** Otherwise `develop`
  accumulates un-rebased historical commits and every future push
  needs a force. Cleanly resolved 3 historical commits (f2d5935,
  4b0c154, 62cfe83) after PR #69 — pattern was: my parser in HEAD
  vs `source ${BOOT_STATE}` in historical commit, always keep
  `--ours`.
- **Commit the regression test in the same branch as the fix.** The
  bats harness (Issue #60) wasn't ready, so I copied the parser
  inline into `test_boot_state_parser.bats` to run against the real
  shell. Both the fix and the test landed in PR #69.
- **Document the *real* vulnerability in the script header.** The
  initial claim ("`set -e` aborts on `confirmed=false`") was
  wrong — bash treats that as a variable assignment, exit 0. The
  *real* defect is command injection via `source` of a writable
  FAT32 file (demonstrated with `INJECTED=$(touch ${SENTINEL})`).
  Comments now explain the actual attack.

**Don't**
- **Don't `source` any file from a writable mount.** `/boot` is FAT32
  and `chmod 666` from the running system. `source boot_state` is
  arbitrary code execution as root, period — no matter what `set -e`
  is set to. Use a read loop, not `source`.
- **Don't trust a single demo command as proof.** I claimed
  `set -e` would abort because `confirmed=false` would be exec'd —
  wrong. `source` returns the last command's exit code, and a bare
  variable assignment is exit 0. Re-validate the threat model from
  scratch before filing a security issue.
- **Don't fight `git rebase` interactively without a clear
  conflict-resolution rule.** When HEAD and the rebased commit both
  rewrite the same file, decide *before* opening the conflict
  markers: this time it was "keep `--ours`" because the parser fix
  is the entire point. For files that should take the historical
  change (e.g. CLAUDE.md updates that diverged), take `--theirs`.
- **Don't leave `develop` ahead of `origin/develop` after a
  squash-merge.** The squash-merge makes origin's tip a new commit;
  the 4–5 historical commits in develop are no longer reachable.
  `git rebase origin/develop` linearizes — do it in the same
  session as the squash-merge, before opening the next issue.