# Acadia-OS — Raspberry Pi 5 / CM5 Hardware Enablement Review

**Board/SoC:** Raspberry Pi 5 and Compute Module 5 (CM5 on the official IO Board), both built around
Broadcom **BCM2712** (4x Cortex-A76 @ up to 2.4 GHz, VideoCore VII GPU) plus the **RP1** southbridge chip
that hangs USB, Ethernet, camera/display MIPI, and most of the GPIO-adjacent peripherals off a PCIe link.
CM5 additionally carries an **RP2040**-class or discrete microcontroller path on some carrier boards for
low-level power sequencing, and Acadia's own project docs note a **Pico W (RP2040)** real-time co-processor
alongside the BCM2712 app processor.

**Current MACHINE targets (verified in `kas/boards/`):**
- `raspberrypi5` — primary target, referenced directly in `build/conf/local.conf` (`MACHINE ??= "raspberrypi5"`) and `kas/boards/rpi5.yaml`.
- `raspberrypi-cm5-io-board` — `kas/boards/cm5.yaml`, shares the RPi5 A/B wks layout (`sdimage-rpi5.wks`).
- Other `kas/boards/*.yaml` (rpi3/rpi4/cm3/cm4/rpi0 variants, generic armv7/armv8) exist but are not the focus of this review — Pi5/CM5 are where `local.conf` and the newest board YAML point.

This document is a **planning/audit artifact only** — no code, recipes, or configs were changed while producing it.

---

## Current State (vanilla gaps)

Acadia-OS builds on `poky` + `meta-openembedded` (`meta-oe`, `meta-python`, `meta-networking`, `meta-multimedia`)
+ `meta-raspberrypi` + `meta-swupdate`, with all platform customization in the locally-committed `meta/meta-acadia`
layer. `meta-raspberrypi` already provides the low-level BSP plumbing (VC4/KMS `vc4-fkms-v3d`/`vc4-kms-v3d`
overlays, RPi firmware/bootloader packaging, `linux-firmware-rpidistro`, `bluez-firmware-rpidistro`, and — because
`meta-multimedia` is pulled into `bblayers.conf` — the dynamic-layer `libcamera-apps` recipe). None of that has to
be re-invented; the gaps below are about what Acadia actually **installs, configures, or wires up** on top of that
BSP baseline.

**What's present today:**
- Ethernet + WiFi (`wpa_supplicant`) + Bluetooth bring-up via `rpi5-connectivity` recipe (systemd-networkd, VLAN10 tagging, BlueZ enabled via preset), plus `iw`/`rfkill`/`bluez5-dev` in the image.
- Generic bus/tool userspace: `i2c-tools`, `python3-smbus`/`smbus2`, `spitools`/`python3-spidev`, `libgpiod`(+tools+python), `can-utils`, `v4l-utils`, `python3-periphery`.
- Serial/UART tooling (`picocom`, `minicom`, `python3-pyserial`) and `ENABLE_UART = "1"` in `common.yaml`.
- Storage/USB tooling: `usbutils`, `pciutils`, `nvme-cli`, `sg3-utils`, `hdparm`, `mtd-utils`.
- Diagnostics: `lshw`, `ethtool`, `devmem2`, `cpupower`, `watchdog` (package only — no config/unit wiring found), `sysstat`, `iotop`, `strace`, `evtest`.
- A/B OTA via `swupdate` + custom `rpi5-swupdate-config` (bootcount, boot-watchdog script, signing hooks) and U-Boot A/B env (`UBOOT_ENV_SUFFIX=scr`, `RPI_USE_U_BOOT=1`).
- gRPC/Protobuf middleware (`packagegroup-acadia-middleware`) and an optional, not-installed-by-default cloud/telemetry group (`packagegroup-acadia-cloud`: mosquitto, chrony, curl).
- SDK/debug tooling: `gdbserver`, `perf`, `trace-cmd`, `valgrind` (excluded on ARMv6 boards), `tools-debug`/`tools-profile`, `ptest-pkgs`.
- A configurable-but-currently-empty kernel config fragment hook (`acadia-base.cfg`) and a configurable-but-empty `ACADIA_EXTRA_CMDLINE`/`LICENSE_FLAGS_ACCEPTED` mechanism — both real extension points, not blockers.
- `GPU_MEM = "128"` set generically; no camera/media-specific GPU memory split for rpi5/cm5.

**What's missing or under-utilized relative to full Pi5/CM5 capability:**
- No camera stack installed (`libcamera`, `libcamera-apps`, `v4l2` pipeline packages) even though `meta-multimedia` is already a bblayer and `meta-raspberrypi`'s dynamic-layer `libcamera-apps` recipe is therefore already reachable — it's just never added to `IMAGE_INSTALL`.
- No hardware video decode/encode packages (`v4l-utils` is present for diagnostics, but no GStreamer VA/V4L2 plugin set, no explicit HEVC/H.265 license-flag acceptance, no `ffmpeg`).
- No PCIe/NVMe boot-firmware config beyond generic `nvme-cli` tooling — no `config.txt`/EEPROM guidance for enabling PCIe Gen3 or NVMe boot order.
- No RTC recipe/config — `hwclock`/RTC battery header (`i2c-rtc` overlay equivalent) not referenced anywhere in `meta-acadia`.
- `watchdog` package is installed but has no found systemd unit, `watchdog.conf`, or `/dev/watchdog` wiring — it's inert as shipped (distinct from the OTA-specific `boot-watchdog.sh` in swupdate, which is a boot-confirmation script, not a hardware watchdog daemon).
- No PWM/1-Wire enablement (no `dtoverlay=w1-gpio`, no `dtparam=pwm` equivalent found in any committed config).
- No fan/thermal control policy — `cpupower` is present for CPU frequency tooling, but nothing manages the official Pi5 Active Cooler / fan header via `dtoverlay` or a thermal daemon.
- No PoE HAT support (no `dtoverlay=rpi-poe`/fan-control service).
- No hardware crypto / secure-boot / dm-verity — `LICENSE_FLAGS_ACCEPTED` mechanism exists but nothing populates it for a signed-boot chain; U-Boot A/B exists for OTA but not for verified/measured boot.
- No JTAG/SWD debug tooling or overlay guidance beyond generic `gdbserver`.
- No environmental/GPS/CAN-transceiver sensor recipes — `can-utils` is present but no `mcp251x` overlay guidance, no example I2C sensor recipe, no GPS/NMEA daemon (`gpsd`).
- Audio stack is entirely absent — no ALSA config, no `alsa-utils`, no I2S/PWM audio overlay guidance.
- No confirmed 4Kp60 dual-HDMI / DRM-KMS tuning beyond whatever `meta-raspberrypi` ships by default (no explicit `vc4-kms-v3d` overlay selection, no multi-display config found in `meta-acadia`).

---

## Features Checklist

### Connectivity
- [ ] On-board 802.11ac WiFi + BT5/BLE firmware/tuning review for Pi5 (CYW43439-class) — confirm `linux-firmware-rpidistro`/`bluez-firmware-rpidistro` (from `meta-raspberrypi`) are actually pulled into `acadia-image.bb`'s `IMAGE_INSTALL`, not just available in the layer.
- [ ] CM5-specific WiFi/BT handling — CM5 Lite/no-wireless SKUs need either an external USB/M.2 WiFi+BT module or a documented "no wireless" board profile; `kas/boards/cm5.yaml` currently makes no distinction.
- [ ] Bluetooth Low Energy (BLE) peripheral-mode tooling (`bluez5` GATT tools, `bluetoothctl` scripting) for IV&V device-pairing workflows.
- [ ] Gigabit Ethernet link diagnostics beyond `ethtool` — e.g. `ethtool -m`/SFP or PoE-negotiation checks if a PoE HAT is used.
- [ ] USB 3.0/2.0 device-class enablement review (mass storage, CDC-ACM/serial gadget, USB-Ethernet gadget) for IV&V test-fixture connections — no gadget-mode config found.
- [ ] PCIe 2.0 x1 link enablement/verification tooling (`lspci`, PCIe Gen3 opt-in via `config.txt`/`dtparam=pciex1_gen=3`) — currently only generic `pciutils` is installed with no board-specific PCIe tuning.

### Camera/Video
- [ ] `libcamera` + `libcamera-apps` (via `meta-raspberrypi`'s dynamic `multimedia-layer` recipe, already reachable since `meta-multimedia` is a bblayer) — add to `IMAGE_INSTALL` for MIPI CSI-2 camera support (Pi5: 2x CSI ports; CM5: more via carrier board/Unicam).
- [ ] `v4l2-relayd` or equivalent V4L2↔RTSP/GStreamer bridging for IV&V camera-feed capture pipelines.
- [ ] Unicam/ISP pipeline validation packages (`libcamera-tools`/`cam` CLI) for bring-up diagnostics on new camera modules.
- [ ] Hardware H.265/HEVC decode enablement — confirm `LICENSE_FLAGS_ACCEPTED` needs to include the HEVC license flag for any proprietary decode path, and add a GStreamer/V4L2 stateless-decoder package set (`gstreamer1.0-plugins-bad` V4L2 codec elements).
- [ ] MIPI DSI display stack validation (`kmscube`/`modetest` from `libdrm-tests`) for touch/display carrier boards.
- [ ] Dual 4Kp60 HDMI / DRM-KMS overlay selection — explicitly pin `vc4-kms-v3d` (full KMS) vs `vc4-fkms-v3d` in a board `local_conf_header`, and document multi-display `config.txt` needs.

### Storage/Boot
- [ ] NVMe boot-order/EEPROM documentation and `rpi-eeprom`/`rpi-eeprom-update` packaging so PCIe NVMe can be a first-class boot device, not just a data volume reachable via `nvme-cli`.
- [ ] eMMC support path for CM5 modules with on-module eMMC (vs. CM5 Lite + external SD/NVMe) — no CM5-eMMC-specific wks/partitioning found; `cm5.yaml` reuses the SD-oriented `sdimage-rpi5.wks` unconditionally.
- [ ] `mtd-utils` is present but no SPI-NOR/flash-based boot config exists for CM5 carrier boards that use it — confirm applicability.
- [ ] A/B rollback watchdog cross-check — `boot-watchdog.sh` (swupdate) handles slot-confirmation, but there's no *hardware* watchdog (`/dev/watchdog` via `bcm2835-wdt`) tying into it for a true "boot-confirm-or-hardware-reset" story.

### GPIO/Sensors/Industrial IO
- [ ] 1-Wire bus enablement (`dtoverlay=w1-gpio` equivalent + `owfs`/`w1-gpio` kernel module) for temperature probes commonly used in IV&V environmental rigs.
- [ ] PWM enablement (`dtoverlay=pwm`/`pwm-2chan`) + userspace PWM control tooling for actuator/motor-control test setups.
- [ ] Example CAN-bus recipe/overlay for an SPI CAN transceiver (`MCP2515`) — `can-utils` is installed but no `dtoverlay=mcp2515-can0` guidance or kernel config (`CONFIG_CAN_MCP251X`) is enabled; the empty `acadia-base.cfg` fragment is the natural home for this, noted inline in that file already.
- [ ] GPIO expander (I2C, e.g. MCP23017/PCF8574) example recipe/overlay for boards needing more digital IO than the 40-pin header exposes directly.
- [ ] Environmental sensor recipes (I2C temp/humidity/pressure — e.g. BME280-class) as a reference pattern for IV&V sensor integration, since these are common companions on Pi-based test rigs.
- [ ] GPS/NMEA support via UART (`gpsd` + `python3-gps`) for location-tagged IV&V telemetry — `picocom`/`pyserial` exist for raw serial access but no GPS daemon/stack.
- [ ] `libgpiod` v2 API confirmation (character-device GPIO, not legacy sysfs) — verify recipe version pulled by `meta-openembedded` pin matches kernel's `gpiochip` ABI.

### Audio
- [ ] ALSA userspace (`alsa-utils`, `alsa-lib` already transitively present via BSP, but no explicit `alsa-utils` in `IMAGE_INSTALL`) for any board using the audio jack, HDMI audio, or I2S HATs.
- [ ] I2S/PWM audio overlay guidance (`dtoverlay=hifiberry-*`/generic I2S codec) for boards pairing DAC/audio HATs — no reference exists today.
- [ ] Basic audio self-test tooling (`speaker-test`, `arecord`/`aplay`) for IV&V audio-path bring-up.

### Display
- [ ] Explicit VC4 KMS driver pinning (see Camera/Video section) and console-on-HDMI vs. headless config documented per board profile.
- [ ] Touchscreen/DSI panel input stack (`xinput`/`libinput` + calibration) if any Acadia deployment profile uses a DSI touch panel.
- [ ] Framebuffer/DRM diagnostic tooling (`modetest`, `drm_info`) for display bring-up in IV&V rigs — not currently installed alongside the `v4l-utils` diagnostics set.

### Power/Thermal
- [ ] Fan/thermal control for the official Pi5 Active Cooler and PoE+ HAT fan header — needs a `dtoverlay` + either kernel thermal-governor tuning or a userspace fan-control daemon (`fancontrol`/custom systemd unit), not present today.
- [ ] PoE HAT (PoE+/rpi-poe) support — `dtoverlay=rpi-poe(-plus)` plus the associated fan/power-negotiation service; no reference in `meta-acadia`.
- [ ] Power/reset button header handling (soft shutdown via GPIO, e.g. `dtoverlay=gpio-shutdown`) for enclosure-mounted IV&V units — not present.
- [ ] `cpupower`/thermal throttling telemetry integration into `acadia-services` (the repo already has a `disk-usage-check` timer pattern that a `thermal-check` service could mirror).
- [ ] RTC battery header support — `i2c-rtc` overlay (e.g. `dtoverlay=i2c-rtc,pcf8523` or DS3231-class) + `hwclock`-at-shutdown/boot systemd hookup for accurate timestamps when offline (relevant given `chrony` is only pulled in via the optional cloud packagegroup).

### Security
- [ ] Secure/verified boot chain — BCM2712/RPi5 supports OTP-based secure boot; nothing in `meta-acadia` references it. Worth scoping against the existing A/B U-Boot flow (`UBOOT_ENV_SUFFIX=scr`) since verified boot changes the trust chain those scripts rely on.
- [ ] dm-verity or equivalent rootfs integrity checking for the A/B slots, complementing the existing SWUpdate RSA-4096/SHA-256 signed-metadata verification (already implemented per `feature.txt` §5) with runtime tamper detection.
- [ ] Hardware crypto/OTP usage — BCM2712 exposes OTP rows for unique IDs/key storage; no recipe or documentation references reading/provisioning these for device identity (relevant for IV&V device attestation).
- [ ] `LICENSE_FLAGS_ACCEPTED` policy documentation — the hook exists (`kas/common.yaml`) but no board currently populates it; worth a decision record for which flags (e.g. HEVC, any closed firmware) each deployment profile accepts.
- [ ] SSH hardening review already exists (`openssh` bbappend with `acadia-hardening.conf` + bats test) — confirm it's extended to cover the operator-account model (`extrausers` locked/SSH-key-only `rpi` user) end-to-end, e.g. host-key regeneration on first boot vs. baked-in keys.

### Debug/Diagnostics
- [ ] JTAG/SWD tooling (`openocd` where applicable) for low-level bring-up debugging beyond `gdbserver`/`perf`/`trace-cmd` — no reference found; RP1/BCM2712 JTAG access pattern should be documented even if tooling stays host-side.
- [ ] Serial-console-over-UART bring-up doc cross-check — `ENABLE_UART=1` is set, but no documented pinout/baud reference for the 40-pin header debug UART in `meta-acadia` docs.
- [ ] `drm_info`/`modetest`/`v4l2-ctl` combined bring-up checklist for new-board validation (ties Camera/Video + Display gaps together into one diagnostic pass).
- [ ] Boot-time diagnostics: `dmesg-capture.service` already exists (`acadia-services`) — good; consider extending with a thermal/undervoltage capture (`vcgencmd get_throttled`-equivalent, since `vcgencmd` itself is Raspbian-specific and would need a Yocto-compatible alternative or explicit packaging decision).

### OTA/Update
- [ ] Kernel/DTB/bootloader (RPi EEPROM) OTA payload support — `feature.txt` §5 notes "kernel, device-tree, bootloader... payloads may be added to the SWUpdate description when the selected platform defines their handlers," but no such handler exists yet for RPi5/CM5 EEPROM updates specifically.
- [ ] Rollback testing/validation harness for the existing bootcount + `boot-watchdog.sh` flow — exists functionally (with bats tests) but worth confirming coverage against a real hardware watchdog once that gap (Power/Thermal section) is closed, since today's "watchdog" naming is boot-confirmation logic, not a `/dev/watchdog` hardware timer.
- [ ] CM5-specific OTA validation — `cm5.yaml` reuses the RPi5 wks/OTA flow as-is; needs an explicit pass confirming partition device naming (`mmcblk0` assumption in `sdimage-rpi5.wks`) holds for CM5 IO-Board eMMC/SD boot paths.

---

## Notes for whoever picks this up

- Several items above are genuinely "flip a switch" work because the enabling layer is already a bblayer (`meta-multimedia` for camera, `meta-raspberrypi` for BSP firmware) — the gap is in `acadia-image.bb`'s `IMAGE_INSTALL` and board `local_conf_header` blocks, not in layer selection.
- The empty `meta/meta-acadia/recipes-kernel/linux/files/fragments/acadia-base.cfg` and empty `ACADIA_EXTRA_CMDLINE ?= ""` in `kas/common.yaml` are pre-built extension points — several checklist items (CAN, 1-Wire, PWM kernel config) slot directly into that fragment file without new recipe scaffolding.
- CM5 has more open questions than Pi5 throughout this doc (wireless variant, eMMC vs SD, wks reuse) because `kas/boards/cm5.yaml` is currently a near-verbatim copy of the Pi5 board file — worth a dedicated CM5 divergence pass before deep-diving individual features.
