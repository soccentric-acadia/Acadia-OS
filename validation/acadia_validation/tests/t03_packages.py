"""t03 — Promised packages & tooling.

Promises: acadia-image.bb IMAGE_INSTALL set, packagegroup-acadia-middleware
(gRPC/Protobuf), ptest-pkgs IMAGE_FEATURE, hardware tooling set.
"""

from acadia_validation.base import FeatureSuite

# Packages explicitly installed by acadia-image.bb (promise source).
REQUIRED_PACKAGES = (
    "polkit nftables chrony mosquitto-clients curl ca-certificates "
    "swupdate swupdate-client rsyslog sudo rt-tests "
    "i2c-tools libgpiod-tools can-utils usbutils ethtool iw "
    "libcamera libcamera-apps gstreamer1.0-plugins-base "
    "gstreamer1.0-plugins-good ffmpeg alsa-utils "
    "gpsd lmsensors rpi-eeprom kmscube libdrm-tests v4l-utils "
    "picocom minicom sysstat watchdog python3-smbus2"
).split()

# CLI tools the operator-visible feature set promises.
REQUIRED_BINARIES = (
    "cyclictest nft chronyd mosquitto_pub swupdate-client "
    "i2cdetect gpiodetect ethtool iw bluetoothctl "
    "rpicam-hello gst-launch-1.0 ffmpeg aplay modetest kmscube "
    "sensors gpsd owserver rpi-eeprom-update"
).split()


class PackagesSuite(FeatureSuite):
    name = "packages"
    description = "Promised packages, middleware libs, ptest, tool binaries"
    groups = ("core", "packages")

    def _package_manager(self) -> str | None:
        r = self.run("command -v rpm >/dev/null && echo rpm || "
                     "(command -v opkg >/dev/null && echo opkg)")
        pm = r.stdout.strip()
        return pm or None

    def _missing_packages(self, pm: str) -> list:
        pkgs = " ".join(REQUIRED_PACKAGES)
        if pm == "rpm":
            cmd = (f"for p in {pkgs}; do rpm -q \"$p\" >/dev/null 2>&1 "
                   f"|| echo \"missing:$p\"; done")
        else:  # opkg
            cmd = (f"I=$(opkg list-installed 2>/dev/null | cut -d' ' -f1); "
                   f"for p in {pkgs}; do echo \"$I\" | grep -qx \"$p\" "
                   f"|| echo \"missing:$p\"; done")
        r = self.run(cmd, timeout=120)
        return [l.split(":", 1)[1] for l in r.stdout.splitlines()
                if l.startswith("missing:")]

    def check_package_manager(self):
        """core-image-full-cmdline base ships package-management."""
        pm = self._package_manager()
        if not pm:
            return self.skipped("no runtime package manager found "
                                "(package-management feature absent)")
        return self.passed(f"{pm} available")

    def check_required_packages_installed(self):
        """Every package acadia-image.bb installs must be on the target."""
        pm = self._package_manager()
        if not pm:
            return self.skipped("no package manager to verify against")
        missing = self._missing_packages(pm)
        if missing:
            return self.failed(f"{len(missing)} missing: "
                               f"{', '.join(missing)}")
        return self.passed(f"all {len(REQUIRED_PACKAGES)} promised "
                           f"packages installed ({pm})")

    def check_middleware_libraries(self):
        """packagegroup-acadia-middleware: gRPC + protobuf libs (no
        compiler on device — M5)."""
        r = self.run("ldconfig -p 2>/dev/null | grep -Eic "
                     "'libgrpc|libprotobuf'")
        count = self.count_lines("ldconfig -p 2>/dev/null | "
                                 "grep -Eic 'libgrpc|libprotobuf'")
        if count > 0:
            return self.passed(f"{count} gRPC/protobuf libraries registered")
        return self.failed("no libgrpc/libprotobuf in ldconfig "
                           "(middleware group broken)")

    def check_ptest_packages(self):
        """IMAGE_FEATURES ptest-pkgs: at least some -ptest packages."""
        count = self.count_lines(
            "rpm -qa 2>/dev/null | grep -c -- -ptest || "
            "opkg list-installed 2>/dev/null | grep -c -- -ptest ")
        if count > 0:
            return self.passed(f"{count} -ptest packages installed")
        return self.failed("no -ptest packages found (ptest-pkgs feature)")

    def check_feature_tool_binaries(self):
        """/usr/bin tools backing the promised feature set."""
        bins = " ".join(REQUIRED_BINARIES)
        r = self.run(f"for b in {bins}; do command -v \"$b\" >/dev/null 2>&1 "
                     f"|| echo \"missing:$b\"; done")
        missing = [l.split(":", 1)[1] for l in r.stdout.splitlines()
                   if l.startswith("missing:")]
        if missing:
            return self.failed(f"{len(missing)} missing tools: "
                               f"{', '.join(missing)}")
        return self.passed(f"all {len(REQUIRED_BINARIES)} promised "
                           f"binaries present")