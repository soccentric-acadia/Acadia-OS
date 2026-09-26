"""t10 — Hardware enablement (BCM2712 + RP1).

Promise source: acadia-image.bb hardware tooling + kas board YAMLs
(PCIe Gen3, KMS, 1-Wire overlay), meta-raspberrypi machine conf (I2C).
Hardware-absent conditions (CAN transceiver, audio HAT) warn, not fail.
"""

from acadia_validation.base import FeatureSuite


class HardwareSuite(FeatureSuite):
    name = "hardware"
    description = "i2c, spi, gpio, uart, pcie, usb, 1-wire, thermal, DRM"
    groups = ("hardware",)

    def check_gpio_chips(self):
        """libgpiod tooling + RP1 GPIO controllers."""
        count = self.count_lines("gpiodetect 2>/dev/null | grep -c .")
        if count > 0:
            chips = self.run("gpiodetect 2>/dev/null | head -2").stdout.strip()
            return self.passed(f"{count} chips: {chips.splitlines()[0]}")
        return self.failed("no gpiochips visible (libgpiod/RP1)")

    def check_i2c_buses(self):
        """i2c-tools + machine-conf I2C enablement."""
        count = self.count_lines("i2cdetect -l 2>/dev/null | grep -c .")
        if count > 0:
            first = self.run("i2cdetect -l 2>/dev/null | head -1").stdout.strip()
            return self.passed(f"{count} buses: {first}")
        if self.machine().startswith(("raspberrypi5", "raspberrypi-cm5")):
            return self.failed("no I2C bus on rpi5/cm5 (machine conf "
                               "enables i2c)")
        return self.warned("no I2C bus (platform-dependent)")

    def check_spi(self):
        """spidev nodes (overlay-dependent)."""
        count = self.count_lines("ls /dev/spidev* 2>/dev/null | grep -c .")
        if count > 0:
            return self.passed(f"{count} spidev node(s)")
        return self.warned("no /dev/spidev nodes (SPI overlay off?)")

    def check_uart_console(self):
        """F04: UART stays the support console (no autologin)."""
        r = self.run("test -e /dev/serial0 || test -e /dev/ttyAMA0")
        if r.ok:
            return self.passed("serial console device present")
        return self.failed("no /dev/serial0 or /dev/ttyAMA0")

    def check_pcie_link(self):
        """PCIe Gen3 opt-in (kas/boards/rpi5.yaml: pciex1_gen=3)."""
        count = self.count_lines("lspci 2>/dev/null | grep -c .")
        if count > 0:
            bridge = self.run("lspci 2>/dev/null | head -1").stdout.strip()
            return self.passed(f"{count} PCI devices: {bridge}")
        return self.failed("lspci reports no PCI devices (RP1 link?)")

    def check_usb(self):
        count = self.count_lines("lsusb 2>/dev/null | grep -c .")
        if count > 0:
            return self.passed(f"{count} USB devices listed")
        return self.failed("lsusb shows nothing")

    def check_onewire_bus(self):
        """kas/common.yaml pins dtoverlay=w1-gpio."""
        r = self.run("test -d /sys/bus/w1")
        if r.ok:
            devices = self.count_lines(
                "ls /sys/bus/w1/devices/ 2>/dev/null | grep -c .")
            return self.passed(f"w1 bus registered "
                               f"({devices} slave(s), devices optional)")
        if self.machine().startswith(("raspberrypi5", "raspberrypi-cm5")):
            return self.failed("no /sys/bus/w1 (w1-gpio overlay promise)")
        return self.warned("no w1 bus (platform-dependent)")

    def check_thermal(self):
        """/sys/class/thermal zones + fan cooling devices (T-P30)."""
        r = self.run("cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null")
        if not r.stdout.strip():
            return self.warned("no thermal zone readable")
        try:
            temp = int(r.stdout.strip()) / 1000
        except ValueError:
            return self.warned("thermal zone unparsable")
        cooling = self.count_lines(
            "ls /sys/class/thermal/ 2>/dev/null | grep -c cooling_device")
        return self.passed(f"CPU {temp:.1f}°C, cooling devices={cooling}")

    def check_can_interfaces(self):
        """can-utils installed; interfaces need a transceiver/HAT."""
        count = self.count_lines(
            "ip -o link show type can 2>/dev/null | grep -c .")
        if count > 0:
            return self.passed(f"{count} CAN interface(s)")
        return self.warned("no CAN interface (transceiver/HAT optional)")

    def check_sensors(self):
        """lm-sensors inspection (hardware-absent tolerated)."""
        count = self.count_lines("sensors 2>/dev/null | grep -c .")
        if count > 0:
            return self.passed(f"{count} sensor output lines")
        return self.warned("sensors returned no chips")

    def check_drm_kms(self):
        """VC4DTBO=vc4-kms-v3d: full KMS promised on rpi5/cm5."""
        count = self.count_lines("ls /dev/dri/ 2>/dev/null | grep -c card")
        if count > 0:
            return self.passed(f"{count} DRM card(s)")
        if self.machine().startswith(("raspberrypi5", "raspberrypi-cm5")):
            return self.failed("no /dev/dri card on rpi5/cm5 (KMS promise)")
        return self.warned("no DRM devices")

    def check_eeprom_tooling(self):
        """rpi-eeprom: NVMe boot-order management (Storage-Boot)."""
        r = self.run("command -v rpi-eeprom-update")
        if not r.ok:
            return self.failed("rpi-eeprom-update missing")
        st = self.run_priv("rpi-eeprom-update 2>&1 | head -3")
        if st is None:
            return self.passed("rpi-eeprom-update present "
                               "(runtime status needs sudo)")
        first = st.stdout.strip().splitlines()[0] if st.stdout.strip() \
            else "no output"
        return self.passed(f"present; {first}")