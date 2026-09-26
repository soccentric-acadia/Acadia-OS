"""t05 — Network & SSH reachability.

Promises: eth0 (gigabit, PoE-capable), wlan0 + BT on wireless SKUs,
sshd (ssh-server-openssh IMAGE_FEATURE), hardened sshd listening on :22.
"""

from acadia_validation.base import FeatureSuite


class NetworkSuite(FeatureSuite):
    name = "network"
    description = "Interfaces, sshd, listening sockets, hostname"
    groups = ("core", "network")

    def _link_state(self, iface: str) -> str | None:
        r = self.run(f"cat /sys/class/net/{iface}/operstate 2>/dev/null")
        return r.stdout.strip() or None

    def check_ethernet(self):
        """Gigabit eth0 (hardware-enablement §1.4)."""
        state = self._link_state("eth0")
        if state is None:
            if self.machine().startswith(("raspberrypi5", "raspberrypi-cm5")):
                return self.failed("eth0 missing on a wired platform")
            return self.warned("eth0 absent (platform-dependent)")
        if state == "up":
            return self.passed("eth0 up")
        return self.warned(f"eth0 present but {state} (cable/link?)")

    def check_loopback(self):
        state = self._link_state("lo")
        if state == "up":
            return self.passed("lo up")
        return self.failed(f"lo state={state!r}")

    def check_wireless(self):
        """wlan0 (CYW43439-class firmware via MACHINE_EXTRA_RRECOMMENDS)."""
        state = self._link_state("wlan0")
        if state is not None:
            return self.passed(f"wlan0 present ({state})")
        if "cm5" in self.machine():
            return self.warned("wlan0 absent — CM5 Lite/no-radio SKU?")
        return self.warned("wlan0 absent")

    def check_bluetooth(self):
        """bluez5 + bluetoothd (hardware-enablement §1.3)."""
        st = self.unit_state("bluetooth.service")
        if st.get("ActiveState") == "active":
            return self.passed("bluetoothd active")
        return self.warned(f"bluetooth service "
                           f"{st.get('ActiveState', 'missing')} "
                           "(radio may be absent)")

    def check_sshd_active(self):
        """ssh-server-openssh IMAGE_FEATURE."""
        st = self.unit_state("sshd.service")
        if st.get("ActiveState") == "active":
            return self.passed("sshd active (suite reaches it over SSH)")
        return self.failed(f"sshd {st.get('ActiveState', 'missing')}")

    def check_ssh_listening(self):
        """:22 listener (implicit proof: this suite connected)."""
        r = self.run("ss -tln 2>/dev/null | grep -c ':22 ' || true")
        count = r.stdout.strip() or "0"
        if count != "0":
            return self.passed("sshd listening on :22")
        return self.warned("sshd not listening on :22 "
                           "(port moved? custom config?)")

    def check_hostname(self):
        r = self.run("hostname")
        name = r.stdout.strip()
        if name:
            return self.passed(f"hostname={name}")
        return self.failed("empty hostname")