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
## C4 — Issue #31 swupdate-webui-auth-init.sh: lessons learned (2026-06-10)

**Do**
- **Distinguish legitimate reveal channels from log channels.** The
  generated web-UI password *must* go to `/dev/console` (the operator
  has no other way to learn it on first boot), but the systemd
  journal is a *log* — anyone in the `systemd-journal` group can
  read it. Always write secrets to the one channel the operator is
  physically present at; never to a system-wide log.
- **Mock all external commands in bats tests.** `openssl`, `md5sum`,
  `install`, `logger`, the journal sink, and `/dev/console` all
  need stubs in `${BIN}` with `${BIN}` prepended to `${PATH}`. The
  recipe's `RDEPENDS` proves the real binaries exist on target, so
  the test only has to prove the script's logic.
- **Test the regression in BOTH directions.** Test 4
  ("plaintext password IS in /dev/console") exists to catch the
  opposite regression — removing the console echo would lock the
  operator out. A security fix that disables the legitimate channel
  is also a bug.
- **Use `sed` to redirect hardcoded device paths in the SUT.** The
  script hardcodes `PASSWD_FILE=/etc/swupdate/...` and
  `> /dev/console`. In the test, `sed` rewrites both to
  `${PASSWD_FILE}` and `${CONSOLE_LOG}` so the script runs
  unprivileged on a host with no systemd. The original file is
  read-only; the test gets a transformed copy in `${TMP}`.

**Don't**
- **Don't use `$'...'` strings with embedded `\n` to construct
  multi-line console banners.** `printf '%s' "${MSG}"` does NOT
  expand the `$'...'` escapes — the literal `\n` characters end
  up in the output. Use `printf '...\n'` per line, or `{ printf ...;
  printf ...; } > /dev/console`.
- **Don't assume `tr -d '=+/' | head -c 12` is 12 chars from the
  input.** The 12-char truncation applies to the *post-tr* output.
  If the input is base64 with `=` and `+`, those are stripped first,
  then 12 chars are taken. Tests must work from the post-truncated
  form, not the pre-truncation form.
- **Don't merge locally before the PR is approved.** Use
  `gh pr merge <N> --squash` (or `--merge` / `--rebase` per repo
  convention). The fast-forward vs squash choice is a project
  policy — match what was used last time. The merge being a
  fast-forward here (vs squash for #69) is fine; the only invariant
  is that `develop` ends up containing the change.
- **Don't forget to record the Do/Don't for every completed issue.**
  This entry is for #31. After C1/C2/C3/C4 the pattern is clear:
  every fix has a "what surprised me" lesson worth keeping. Skip
  this and the next contributor repeats the mistake.

## C5 — Issue #26 swupdate-bootcheck size bounds: lessons learned (2026-06-10)

**Do**
- **Per-file size bounds require a `case` block, not a shared `||`.**
  A health check that always reports unhealthy is worse than no
  health check — the DTB-always-fails-1MB-gate bug went unnoticed
  for the entire C1 cycle because the symptom was "OTA always
  rolls back on first boot", which is a plausible misdiagnosis
  for the rest of the rollback chain. The fix is a per-file
  `case "${f}" in kernel_*) ... ;; *-rpi-*-b.dtb) ... ;; esac`
  with explicit min/max per family, plus a generic `*)` fallback
  that *warns* (not fails) so a new SoC's filename doesn't
  silently break rollback.
- **Inline the test logic from the production script.** Both
  `swupdate-bootcheck.sh` and `boot-watchdog.sh` carry the same
  `case` block. `tests/test_size_bounds.bats` copies it inline
  and exercises 7 cases (healthy kernel, healthy DTB, zero-byte
  kernel, too-small DTB, oversize kernel, oversize DTB, RPi 4
  DTB wildcard). When the production case changes, the test
  must change in the same commit.
- **Test the bounds via a per-test fixture, not a shared setup.**
  Earlier drafts created a 7 MB kernel and 60 KB DTB in
  `setup()` and then had the oversize tests overwrite them —
  fragile. Each `@test` now creates the file it needs with
  `dd`, and `teardown()` cleans the tempdir.  One file, one
  assertion, one fixture.

**Don't**
- **Don't pass a full path into a `case` block that expects the
  basename.** `case "${f}" in kernel_2712.img)` is a literal
  match — `case "/tmp/foo/kernel_2712.img"` falls through to
  the generic `*)` branch with the wider 50 MB upper bound, so
  a 26 MB "kernel" passes silently. The production code is
  correct because it iterates `for f in kernel_2712.img ...`
  and uses `${f}` (basename) for `case` and `/boot/${f}` for
  `stat`. When inlining into a test, mirror that split: the
  function takes a basename, the function uses `${TMP}/${f}`
  for the `stat` call.
- **Don't share a single 1 MB / 10 MB bound across kernel and
  DTB.** This is the bug; repeating it here so the next
  contributor sees it. kernel_2712.img is 7-15 MB.
  bcm2712-rpi-5-b.dtb is 50-80 KB. The 1 MB gate excludes
  every DTB; the 10 MB ceiling excludes every RPi 5 kernel.
  Both ranges are wrong; per-file is the only correct answer.
- **Don't ship a health check that emits only a `logger` line
  on failure.** A `WARN: kernel size outside [1MB, 10MB]`
  log line is invisible in a CI pipeline that doesn't
  journal-persist. The fix is to set `HEALTH_OK=false` *and*
  continue iterating (the existing `break` is correct) so
  the rollback path runs immediately. A logged warning
  without an action is just noise.

## C6 — Issue #59 openssh Include directive: lessons learned (2026-06-10)

**Do**
- **Anchor every `grep` that guards a config-file patch.** The
  unanchored `'Include.*sshd_config\.d'` matched the
  *commented-out* line too, so when upstream sshd_config
  shipped `# Include /etc/ssh/sshd_config.d/*.conf` the
  recipe skipped the prepend silently.  The fix is
  `'^[[:space:]]*Include[[:space:]]+.*sshd_config\.d'`.  This
  pattern matches the directive *as written* — leading
  whitespace tolerated (some distros indent), comments
  rejected.
- **Fail loudly in a build recipe when a *runtime* invariant
  isn't met.** BitBake's `bbfatal` aborts the build with a
  visible error in the build log; a missing Include at boot
  is invisible (sshd just ignores unknown config keys).  The
  re-grep + bbfatal is a 4-line post-condition that turns a
  security regression into a build break.
- **Test the regression in BOTH directions.** Test 2 covers
  the original bug (commented Include is not enough) and
  test 3 covers the opposite: a *real* Include on the first
  line is not duplicated.  Both directions matter —
  a fix that "always prepends" would pass test 2 and
  silently break test 3.

**Don't**
- **Don't rely on an unanchored `grep` to detect a config
  directive.** A `grep -q Include` will always match —
  comments, substrings, even a `Setting "Include"` line in
  documentation.  Anchor with `^[[:space:]]*` (matches
  start-of-line, ignoring leading whitespace) and a
  whitespace-separator before the argument (`Include[[:space:]]+`)
  to rule out "Includesomething" or "IncludePath".
- **Don't put `bbfatal` in a subshell or after `set -e`
  recovery.** The current code uses `|| true` on the sed
  failure so the post-condition check can still run; this
  is intentional.  If the sed fails AND the grep finds no
  Include, the build aborts.  If you `set -e` the
  whole block, a failed sed would never trigger the
  post-condition grep.
- **Don't write a bats test for an *empty* file case that
  the production code can't actually hit.** BitBake's
  `do_install` always receives a non-empty upstream
  `sshd_config` (it's a config file shipped by openssh,
  not a user-generated blank).  Test the realistic
  whitespace-only case instead.  A test for "empty file"
  is a "test for the test's sake" — the next refactor
  will be tempted to "fix" the production code to handle
  empty input, and discover the test was guarding a
  non-existent scenario.

## C7 — Issue #21 SWUpdate RSA signing: lessons learned (2026-06-10)

**Do**
- **Ship a throwaway-but-valid placeholder for the public key.**
  A PEM with `-----BEGIN PUBLIC KEY-----\nPLACEHOLDER` is
  not a valid RSA key — `swupdate -k` will fail to parse it
  and the daemon will refuse to start.  Either ship nothing
  (and have the recipe `bbfatal` if the file is missing) or
  ship a real RSA-2048 key with a clear "REPLACE ME" header
  comment.  The placeholder is a *valid* key, so the image
  boots; the matching *private* key is never committed, so
  the .swu is unverifiable.  This forces the operator (or
  the CI vault) to do the right thing.
- **Use `SWUPDATE_SIGNING` per the meta-swupdate README.**
  meta-swupdate ships its own RSA signing helper
  (`SWUPDATE_SIGNING = "RSA"` + `SWUPDATE_PRIVATE_KEY`); the
  existing Makefile hand-rolls the same flow.  Both work;
  the Makefile path is the "we control the package layout"
  route, the meta-swupdate path is the "let BitBake do it"
  route.  Match the route the project's other recipes use —
  Acadia-OS is currently hand-rolled, so stay consistent.
  If you migrate to meta-swupdate's helper, deprecate the
  Makefile block; do not run both.
- **Make the gate fail-closed with an opt-out env var.**
  A missing private key is a *production* error, not a
  warning.  `make swu` must exit 1 by default.  Provide a
  deliberate escape hatch (`SWU_ALLOW_UNSIGNED=1`) so the
  build pipeline can iterate on the rest of the .swu
  (rootfs, kernel, DTB) without needing a real key.  The
  on-target swupdate daemon still rejects the resulting
  .swu, so the operator can never accidentally ship it.

**Don't**
- **Don't `env VAR= function` in bats.** Functions live in
  the current shell; `env` runs its argument in a child
  process where the function isn't visible.  `command not
  found`.  Use `( VAR=val function )` — the parens force
  a subshell, but in this subshell the *parent* shell's
  function table is still visible (functions are
  inherited).  `gate_with` in the test does this.
- **Don't `VAR= cmd` as a one-liner test assertion in bats.**
  `SWU_ALLOW_UNSIGNED= check_swu_gate ...` sets VAR=empty
  for `check_swu_gate` and then propagates the function's
  exit code to the test body.  If the function returns 1
  (the expected case for "empty should NOT bypass the
  gate"), the test body exits 1 and the test fails with
  the wrong reason.  Always wrap in `run ... ; [ "$status"
  -eq 0 ]` or `!` for the inverse.
- **Don't commit a `-----BEGIN PUBLIC KEY-----` block with
  literal "PLACEHOLDER" text.** It's not a valid PEM, the
  swupdate parser will reject it, and the entire image will
  fail to boot.  The placeholder must be a *valid* key
  (real RSA modulus), just one whose private half is not
  in the repo.  The signed-by-the-throwaway path won't
  be useful to an attacker, and any real .swu signed by
  the production private key won't verify against the
  throwaway public key, so the operator will get a loud
  "signature mismatch" on first install.

## C8 — Issue #56 dmesg-capture journal pipe: lessons learned (2026-06-10)

**Do**
- **Pipe diagnostic data to systemd-cat, never redirect to `/var/log/`.**
  Poky makes `/var/log` a symlink to `/var/volatile/log` by default,
  so any file written there is lost on reboot.  The persistent
  journal lives in `/var/log/journal/` (bind-mounted to persistent
  storage under meta-acadia's storage layout) and survives across
  reboots.  `systemd-cat -t <tag> -p <prio>` is the canonical
  pipe; the tag becomes the syslog identifier for `journalctl -t`.
- **Order `After=systemd-journald.service` for any service that
  pipes into systemd-cat.**  Without it, the pipe can block on a
  journald that isn't yet accepting messages, or silently drop
  entries.  This is the same lesson as the bootcount-reset
  ordering fix: order unit dependencies on the *socket*, not the
  network.
- **Add explicit `RDEPENDS:${PN} = "systemd util-linux"` for any
  recipe that uses systemd-cat or dmesg.**  They're pulled in by
  core-image-full-cmdline, but a future image that doesn't ship
  them (e.g. a minimal Acadia variant) will fail at first boot
  with `systemd-cat: command not found`.  Better to be explicit.
- **Anchor the bats `SUT` path with enough `../` segments.**  The
  canonical pattern is `${BATS_TEST_DIRNAME}/../../../recipes-...`,
  not `${BATS_TEST_DIRNAME}/../files/...`.  Tests live under
  `recipes-<cat>/<recipe>/tests/`, so the relative path is three
  segments up.  This is consistent with the other Acadia tests.

**Don't**
- **Don't add `--since=@0` and `-p info` as cosmetic changes —
  the *behavior* is what matters.**  `--since=@0` reads the full
  ring buffer (the default reads since uptime, which is fine on
  fresh boot but loses the early messages on slow systems).  `-p
  info` keeps the entry in the journal's default priority filter.
  Both are correctness, not cosmetics.
- **Don't push the branch from `develop` if a `fix/<#>-*` branch
  already exists.**  The first attempt landed on develop because
  the auto-checkout in this session put HEAD on develop after the
  issue comment.  Always verify the branch before `git commit` —
  the branch name in the issue comment is the contract.

## C9 — Issue #54 pre-install slot label: lessons learned (2026-06-10)

**Do**
- **Anchor on persistent identifiers (PARTUUID, GPT label, FS
  UUID), not block-device paths.**  Block-device paths are
  kernel-assigned, hardware-dependent, and change between SD,
  NVMe, and USB boot.  The WKS already gives us `rootfs-a` /
  `rootfs-b` labels, so use them.  This is the same pattern as
  `findmnt -no SOURCE /` for the active device — but the label
  layer is the one that survives across the block-device-type
  transition.
- **For `lsblk -n -o LABEL <dev>`, the device is the LAST
  positional arg, with `-n -o LABEL` before it.**  When stubbing
  `lsblk` in a bats test, scan all `$@` for the device path —
  don't assume `$1` is the device.  The actual call shape is
  `lsblk -n -o LABEL /dev/mmcblk0p2`, so a case on `$1`
  matches `-n`, not the device.
- **When the script under test writes to `/dev`, `/run`, or
  other privileged paths, sed-rewrite the script into TMP and
  run the copy.**  Don't try to fake `/dev` or `/run` with
  bind-mounts (needs root) or with namespace tricks (not
  portable).  A 3-line `sed -e 's|/dev/foo|TMP/foo|g' file >
  TMP/file` is the simplest correct test harness, and the diff
  to the original is fully visible for review.
- **Stub external commands via PATH-prepended shim directory,
  not via `alias` or function override.**  `alias` is
  non-interactive-only; function override doesn't survive
  `bash subshell`.  A `BIN=$(mktemp -d)` directory with
  executable stubs prepended to PATH is the only thing that
  consistently works in a bats `run` block.

**Don't**
- **Don't use `! grep -qE 'mmcblk0p[23]' file` if the file
  *comment* legitimately references the old behaviour.**  The
  defensive test I wrote initially failed because the issue
  comment in the new script *says* "previous version hardcoded
  /dev/mmcblk0p2/p3".  Anchor the regex on the syntactic
  context (case-arm `(/dev/...)`, assignment `INACTIVE_DEV=
  /dev/...`) — the comment is just documentation, not a
  regression.
- **Don't pre-write stubs at bats-gather time (top of file
  outside any function).**  bats runs gather at parse time,
  before any test's `setup()` has run, so `${BIN}` and `${TMP}`
  are unset.  All stub installation belongs in `setup()`.

## C10 — Issue #113 sw-description per-board templating: lessons learned (2026-06-17)

**Do**
- **Tokenize *every* per-board field in the sw-description, not
  just the version.**  The previous sed pipeline substituted
  `@@VERSION@@` but left the `kernel_2712.img` /
  `bcm2712-rpi-5-b.dtb` filenames hardcoded — so the .swu
  referenced filenames that didn't exist in the cpio for any
  non-rpi5 board, and SWUpdate would reject the install with
  "rawfile file not found".  Three tokens (version, kernel,
  DTB), three sed `-e` expressions.  Order doesn't matter; the
  `g` flag does.
- **Anchor the recipe in three places.**  Source: `sw-description`
  must contain the `@@KERNEL@@` / `@@DTB@@` tokens
  (regression test #1).  Build: Makefile's sed pipeline must
  substitute all three tokens with `g` (regression test #6/7/8).
  Output: end-to-end `sed` run against a per-board value must
  produce a sw-description with **zero** remaining `@@` tokens
  (regression test #11).  The third anchor catches a silent
  sed-regex typo that the source/build anchors miss.
- **Compute the SUT path from `BATS_TEST_DIRNAME` as a
  relative number of `..` segments, then verify with
  `realpath`.**  Tests under
  `meta/meta-acadia/recipes-swupdate/<recipe>/tests/` are
  *five* levels deep: tests → recipe → recipes-swupdate →
  meta-acadia → meta → Acadia-OS.  Use `../../../../../Makefile`
  and `../../../../../meta/...`, not four segments up.  The
  recipe-level tests use `../files/` (one segment up), which
  is *not* portable to a tests/ subdir of a recipe.

**Don't**
- **Don't use `grep -qE` for shell tokens that contain
  Makefile variable references.**  The patterns
  `s|@@KERNEL@@|$(SWU_KERNEL)|g` contain literal `$` and `(`,
  and `grep -E` treats `$` as line-anchor.  The first regex
  pattern with `\$\(` matched 0 lines because grep was
  looking for `$(SWU_KERNEL)` (literal parens) which never
  appears — the file has `$(SWU_KERNEL)` after Make
  expansion but grep reads the file *unexpanded*.  Use
  `grep -qF` (fixed string) for patterns containing `$`,
  `(`, `)`, `|`, etc.  Reserve `-E` for patterns that need
  regex anchors or character classes.
- **Don't assume the bats `setup()` function inherits
  environment variables from the parent.**  `TEST_KERNEL=foo
  bats ...` sets `TEST_KERNEL` in the bats harness, but
  `setup()` is a child function — the variable is exported
  via `export TEST_KERNEL=foo` first.  The cleanest pattern
  is to read the default in `setup()` itself (`${TEST_KERNEL
  :-kernel_2711.img}`), then per-test overrides use
  `TEST_KERNEL=... bats ...` which bats *does* export
  automatically.  Don't try to set env vars in the bats
  test body — they don't propagate to `setup()`.
- **Don't run `make -n swu BOARD=<x>` and read the recipe
  text as proof the fix works.**  `make -n` shows the
  *recipe* (unexpanded `$()` references) by default because
  it must preserve the recipe for dry-run display.  The
  Make variables are visible only via `make -n -p` (print
  database) or by running the sed pipeline directly against
  the values you want.  When verifying per-board templating,
  always run the actual `sed -e ... -e ...` command with the
  real `SWU_KERNEL` / `SWU_DTB` values and inspect the
  output.

