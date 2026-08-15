#!/usr/bin/env bats
# test_hardware_enablement.bats — regression test for the task.md
# hardware-enablement pass (camera/video, audio, sensors, display,
# power/thermal, storage/boot, debug).  Pins the presence of the new
# package wiring, kernel config, board YAML, and service units so a
# future refactor cannot silently drop them.

setup() {
    ROOT="${BATS_TEST_DIRNAME}/../.."
    IMG="${ROOT}/meta/meta-acadia/recipes-core/images/acadia-image.bb"
    COMMON="${ROOT}/kas/common.yaml"
    CFG="${ROOT}/meta/meta-acadia/recipes-kernel/linux/files/fragments/acadia-base.cfg"
    SVC="${ROOT}/meta/meta-acadia/recipes-core/acadia-services/acadia-services.bb"
    DOC="${ROOT}/meta/meta-acadia/docs/hardware-enablement.md"
}

# --- Camera / Video ---------------------------------------------------------

@test "acadia-image.bb: installs libcamera + libcamera-apps" {
    grep -qF 'libcamera libcamera-apps' "${IMG}"
}

@test "acadia-image.bb: installs GStreamer + ffmpeg for HEVC decode" {
    grep -qF 'gstreamer1.0-plugins-base gstreamer1.0-plugins-good' "${IMG}"
    grep -qF 'gstreamer1.0-plugins-bad gstreamer1.0-libav' "${IMG}"
    grep -qF 'ffmpeg' "${IMG}"
}

@test "gstreamer1.0-plugins-bad bbappend: enables v4l2codecs" {
    BB="${ROOT}/meta/meta-acadia/recipes-multimedia/gstreamer/gstreamer1.0-plugins-bad_%.bbappend"
    [ -f "${BB}" ]
    grep -qF 'PACKAGECONFIG:append = " v4l2codecs"' "${BB}"
}

# --- Display / Audio --------------------------------------------------------

@test "acadia-image.bb: installs kmscube + libdrm-tests (modetest)" {
    grep -qF 'kmscube libdrm-tests' "${IMG}"
}

@test "acadia-image.bb: installs alsa-utils" {
    grep -qF 'alsa-utils' "${IMG}"
}

# --- Sensors / GPS / 1-Wire -------------------------------------------------

@test "acadia-image.bb: installs gpsd + python bindings" {
    grep -qF 'gpsd gpsd-conf gps-utils python3-pygps python3-gpsd-py3' "${IMG}"
}

@test "acadia-image.bb: installs owfs (1-Wire)" {
    grep -qF 'owfs owserver owshell' "${IMG}"
}

@test "kas/repos/meta-openembedded.yaml: adds meta-filesystems for owfs" {
    grep -qF 'meta-filesystems' "${ROOT}/kas/repos/meta-openembedded.yaml"
}

# --- Power / Thermal --------------------------------------------------------

@test "acadia-image.bb: installs lm-sensors + fancontrol" {
    grep -qF 'lmsensors lmsensors-sensors lmsensors-fancontrol lmsensors-config' "${IMG}"
}

@test "acadia-services.bb: provides thermal-check, fan-control, rtc-sync, watchdog" {
    grep -qF 'thermal-check.service' "${SVC}"
    grep -qF 'fan-control.service' "${SVC}"
    grep -qF 'rtc-sync.service' "${SVC}"
    grep -qF '80-acadia-watchdog.preset' "${SVC}"
    grep -qF 'watchdog.conf' "${SVC}"
}

@test "acadia-services: watchdog preset enables watchdog.service" {
    grep -qF 'enable watchdog.service' \
        "${ROOT}/meta/meta-acadia/recipes-core/acadia-services/files/80-acadia-watchdog.preset"
}

# --- Storage / Boot ---------------------------------------------------------

@test "acadia-image.bb: installs rpi-eeprom for NVMe boot-order management" {
    grep -qF 'rpi-eeprom' "${IMG}"
}

# --- Debug / Diagnostics ----------------------------------------------------

@test "acadia-image.bb: installs openocd for JTAG/SWD" {
    grep -qF 'openocd' "${IMG}"
}

# --- kas/common.yaml overlays + license -------------------------------------

@test "kas/common.yaml: RPI_EXTRA_CONFIG enables w1-gpio, pwm, mcp2515, rpi-poe, gpio-shutdown, i2c-rtc" {
    grep -qF 'dtoverlay=w1-gpio' "${COMMON}"
    grep -qF 'dtoverlay=pwm' "${COMMON}"
    grep -qF 'dtoverlay=mcp2515-can0' "${COMMON}"
    grep -qF 'dtoverlay=rpi-poe' "${COMMON}"
    grep -qF 'dtoverlay=gpio-shutdown' "${COMMON}"
    grep -qF 'dtoverlay=i2c-rtc' "${COMMON}"
}

@test "kas/common.yaml: accepts commercial license flag for HEVC" {
    grep -qF 'LICENSE_FLAGS_ACCEPTED ?= "commercial"' "${COMMON}"
}

# --- Kernel config fragment -------------------------------------------------

@test "acadia-base.cfg: enables CAN, 1-Wire, PWM, RTC, watchdog, sensors" {
    grep -qF 'CONFIG_CAN_MCP251X=y' "${CFG}"
    grep -qF 'CONFIG_W1_MASTER_GPIO=y' "${CFG}"
    grep -qF 'CONFIG_PWM_BCM2835=y' "${CFG}"
    grep -qF 'CONFIG_RTC_DRV_PCF8523=y' "${CFG}"
    grep -qF 'CONFIG_BCM2835_WDT=y' "${CFG}"
    grep -qF 'CONFIG_BME280=y' "${CFG}"
}

# --- Board YAMLs ------------------------------------------------------------

@test "rpi5.yaml: pins vc4-kms-v3d, enables vc4graphics, PCIe Gen3, camera GPU" {
    grep -qF 'VC4DTBO = "vc4-kms-v3d"' "${ROOT}/kas/boards/rpi5.yaml"
    grep -qF 'MACHINE_FEATURES:append = " vc4graphics"' "${ROOT}/kas/boards/rpi5.yaml"
    grep -qF 'dtparam=pciex1_gen=3' "${ROOT}/kas/boards/rpi5.yaml"
    grep -qF 'GPU_MEM = "${GPU_MEM_CAMERA}"' "${ROOT}/kas/boards/rpi5.yaml"
}

@test "cm5.yaml: documents no-wireless profile, pins KMS, PCIe Gen3" {
    grep -qF 'CM5 Lite / no-wireless' "${ROOT}/kas/boards/cm5.yaml"
    grep -qF 'VC4DTBO = "vc4-kms-v3d"' "${ROOT}/kas/boards/cm5.yaml"
    grep -qF 'dtparam=pciex1_gen=3' "${ROOT}/kas/boards/cm5.yaml"
}

# --- Documentation ----------------------------------------------------------

@test "docs/hardware-enablement.md exists and covers secure boot, JTAG, serial" {
    [ -f "${DOC}" ]
    grep -qF 'Secure / verified boot' "${DOC}"
    grep -qF 'JTAG/SWD' "${DOC}"
    grep -qF 'Serial console' "${DOC}"
    grep -qF 'USB gadget' "${DOC}"
    grep -qF 'NVMe boot-order' "${DOC}"
}
