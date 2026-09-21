# Changelog

## 2026-09-21 — Persistent 1 GB `/pst` partition (task 003)

### Added

- The A/B OTA SD image (`sdimage-rpi5.wks`, boards `rpi5` and `cm5`) now has
  a dedicated persistent store partition: **p4 `/pst`, 1 GB fixed, ext4,
  label `pst`** — never written by SWUpdate, so alarm state, collected logs,
  backups, and istate-seeded configuration survive every software update.
- New `acadia-pst-init` recipe shipping the rootfs-packaged `pst.mount`
  systemd unit (`LABEL=pst`, silently skipped on devices with the old
  4-partition layout), the `acadia-pst-init.service` ownership bootstrap
  (`instr-istate:instr`, setgid 2770, per-spoke store directories), and an
  `instr-istate.service` ordering drop-in. Installed on `raspberrypi5` and
  `raspberrypi-cm5-io-board`.
- Partition table switched from msdos to **GPT** (`--ptable gpt`): five data
  partitions exceed the msdos four-primary limit and its extended-container
  fallback would trap the last partition, breaking `/home` growth to fill
  the card. GPT is also required for RPi5 secure boot and CM5 NVMe boot.

### Fixed

- The `/home` partition (now p5) is mkfs'd: `--source empty` in this poky
  creates unformatted (all-zero) partitions, so `/home` could never mount
  from a fresh flash. Both `/home` and `/pst` now omit `--source` and get a
  formatted empty ext4 volume; `rootfs-b` (p3) keeps `--source empty`
  deliberately (SWUpdate raw-writes the complete rootfs onto it).
- `rpi5-home-init` growth logic is unchanged (the partition number is
  derived at runtime; `/home` remains the last partition).

### Validation

All changes are in the meta-acadia layer (nested clone, commit `5bbaeb2`); the
outer repo changes are the task records and this changelog entry only.
Full `make build rpi5` green (10,145 tasks); `make test-wiring` green; bats
suites green (pst-init 17/17, swupdate-config 72/72, home-init 16/16);
built-artifact inspection confirms the GPT layout, `pst`/`home` volume
names, unchanged fstab, and the units present in both the factory `.wic` and
the OTA-packaged `.rootfs.ext4`. On-target OTA round-trip pending hardware
access — see `tasks/003-add-pst-partition/validation.md`.

Pre-existing `lint-reproducibility` AUTOREV failures (acadia-client,
webconfigd) are unrelated to this task.

## 2026-09-21 — PREEMPT_RT kernel for aarch64 (task 002)

### Added

- The aarch64 Acadia kernel is now a PREEMPT_RT real-time kernel: upstream
  `patch-6.6.78-rt51` (GPG-verified against the kernel.org RT maintainer key)
  applied on top of the pinned `rpi-6.6.y` SRCREV `bba53a1` (6.6.78) via the
  meta-acadia `linux-raspberrypi_6.6.bbappend`, with a new
  `files/fragments/preempt-rt.cfg` selecting `CONFIG_PREEMPT_RT=y`.
- `acadia-image` ships `rt-tests` 2.6 (cyclictest/hackbench/hwlatdetect) for
  latency measurement in the field and on the test bench.
- Built kernel banner: `Linux version 6.6.78-rt51-v8-16k … #1 SMP PREEMPT_RT`.
- 32-bit armv7 machines (`linux-raspberrypi-v7`) are intentionally out of
  scope and keep the stock (non-RT) kernel (task 002 decision D1).

### Changed

- meta-acadia commit `4af0d5a` (vendored patch + fragment + bbappend +
  image); full rpi5 image build and `make test-wiring` green.
- On-target validation (boot identity, cyclictest, peripherals, SWUpdate A/B)
  pending hardware access — see
  `tasks/002-add-preempt-rt-kernel-patch/validation.md` for the procedure.

All changes are in the meta-acadia layer (nested clone); no outer-repo files
modified.

## 2026-09-18 — Agent documentation and task workflow standardization

- Replaced the detailed root `CLAUDE.md` with a canonical pointer and added
  `AGENTS.md`.
- Added a concise canonical document with Yocto image-build and layer-wiring
  validation instructions.
- Added ignored local `Plan.md` and `Task.md` workflow artifacts.
- Verified the required document shape and the declared `make build` and
  `make test-wiring` targets.

## [Unreleased]

### Added — hardware enablement (task.md)

- **Camera/Video**: `libcamera` + `libcamera-apps` (rpicam-* tools), GStreamer
  (`gstreamer1.0-plugins-base/good/bad`, `gstreamer1.0-libav`) + `ffmpeg` for
  H.265/HEVC decode; `v4l2codecs` PACKAGECONFIG enabled via a new
  `gstreamer1.0-plugins-bad` bbappend; `commercial` license flag accepted in
  `kas/common.yaml`.  `acadia-camera` gains a `MODE=udp` V4L2-to-RTP/JPEG
  streaming bridge (using only `gstreamer1.0-plugins-good`) for IV&V
  camera-feed capture pipelines (task.md Camera-Video).
- **Display**: `kmscube` + `libdrm-tests` (modetest); `vc4-kms-v3d` pinned and
  `vc4graphics` enabled per-board.
- **Audio**: `alsa-utils` (aplay/arecord/speaker-test).
- **Sensors/Industrial IO**: `gpsd` + python bindings, `owfs` (1-Wire),
  `lm-sensors` + `fancontrol`; kernel config for CAN (MCP251X), 1-Wire, PWM,
  GPIO expanders, BME280, RTC, and the BCM2835 hardware watchdog in
  `acadia-base.cfg`.
- **Storage/Boot**: `rpi-eeprom` for NVMe boot-order/EEPROM management;
  `meta-filesystems` added to the kas repo for owfs.
- **Debug**: `openocd` for JTAG/SWD.
- **Power/Thermal**: `acadia-services` now ships `thermal-check`, `fan-control`,
  `rtc-sync` (boot read / shutdown write), and a hardware-watchdog preset
  (`80-acadia-watchdog.preset` enabling `watchdog.service`).
- **Board YAMLs**: rpi5/cm5 pin `vc4-kms-v3d`, opt in to PCIe Gen3
  (`dtparam=pciex1_gen=3`), raise `GPU_MEM` for the camera, and document the
  CM5 no-wireless profile.
- **Docs**: `meta/meta-acadia/docs/hardware-enablement.md` covering secure
  boot, dm-verity, OTP, JTAG/SWD, serial console, USB gadget, NVMe boot order,
  and a combined bring-up checklist.
- **Tests**: `scripts/tests/test_hardware_enablement.bats` and
  `recipes-core/acadia-services/tests/test_health_services.bats`.

### Added — project documentation

- **User accounts**: `acaida` login account (password `acaida`, SHA-512-crypt
  via `extrausers`) with home `/home/acaida` created on the persistent p4
  partition by `rpi5-home-init` on first boot (`acadia-image.bb`, inherited by
  all vertical images).
- **`CLAUDE.md`** and **`REPO_MAP.md`** — project documentation matching the
  fleet-wide convention.

### Notes

- Acadia-OS is the **reference/baseline** platform for the SiliconCentric
  fleet. It is the most fully built-out OS repo (146 files): complete
  `meta/meta-acadia` Yocto layer, 20 per-domain image variants, A/B OTA via
  swupdate with full rollback (boot-watchdog, bootcount-reset,
  swupdate-bootcheck), `rpi5-home-init`, connectivity, HAL, and a suite of
  Bats tests. Other platforms port from this template.
