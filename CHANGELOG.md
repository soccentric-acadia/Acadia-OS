# Changelog

## [Unreleased]

### Added — hardware enablement (task.md)

- **Camera/Video**: `libcamera` + `libcamera-apps` (rpicam-* tools), GStreamer
  (`gstreamer1.0-plugins-base/good/bad`, `gstreamer1.0-libav`) + `ffmpeg` for
  H.265/HEVC decode; `v4l2codecs` PACKAGECONFIG enabled via a new
  `gstreamer1.0-plugins-bad` bbappend; `commercial` license flag accepted in
  `kas/common.yaml`.
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

- **`CLAUDE.md`** and **`REPO_MAP.md`** — project documentation matching the
  fleet-wide convention.

### Notes

- Acadia-OS is the **reference/baseline** platform for the SiliconCentric
  fleet. It is the most fully built-out OS repo (146 files): complete
  `meta/meta-acadia` Yocto layer, 20 per-domain image variants, A/B OTA via
  swupdate with full rollback (boot-watchdog, bootcount-reset,
  swupdate-bootcheck), `rpi5-home-init`, connectivity, HAL, and a suite of
  Bats tests. Other platforms port from this template.
