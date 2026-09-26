"""t12 — Time & clock chain.

Promises: chrony (GNSS time chain P-D05), RTC on rpi5/cm5, rtc-sync units
(acadia-services), timesyncd-acadia.conf drop-in (systemd bbappend).
"""

from acadia_validation.base import FeatureSuite


class TimeSyncSuite(FeatureSuite):
    name = "time-sync"
    description = "chrony, RTC hardware, rtc-sync units, NTP sync state"
    groups = ("time", "core")

    def check_rtc_device(self):
        """/dev/rtc0 — Pi 5 exposes an onboard RTC."""
        r = self.run("test -e /dev/rtc0 && echo yes")
        if r.ok:
            return self.passed("/dev/rtc0 present")
        if self.machine().startswith(("raspberrypi5", "raspberrypi-cm5")):
            return self.failed("no /dev/rtc0 on rpi5/cm5")
        return self.warned("no RTC device")

    def check_chrony_active(self):
        """chrony is the promised time daemon (P-D05)."""
        st = self.unit_state("chronyd.service") or \
            self.unit_state("chrony.service")
        if st.get("ActiveState") == "active":
            return self.passed("chronyd active")
        return self.failed(f"chrony not active "
                           f"({st.get('ActiveState', 'missing')})")

    def check_chrony_config(self):
        r = self.run("test -e /etc/chrony.conf || test -e /etc/chrony/chrony.conf")
        if r.ok:
            return self.passed("chrony configuration present")
        return self.failed("no chrony.conf found")

    def check_rtc_sync_units(self):
        """rtc-sync.service + rtc-sync-shutdown.service (acadia-services)."""
        res = self.expect_unit("rtc-sync.service", allow_inactive=True)
        if res.status.value == "FAIL":
            return res
        res2 = self.expect_unit("rtc-sync-shutdown.service",
                                allow_inactive=True)
        if res2.status.value == "FAIL":
            return res2
        return self.passed("rtc-sync + rtc-sync-shutdown healthy "
                           f"({res.detail}; {res2.detail})")

    def check_ntp_synchronized(self):
        """timedatectl reports sync (bench without internet → WARN)."""
        r = self.run("timedatectl show -p NTPSynchronized 2>/dev/null")
        if "yes" in r.stdout:
            return self.passed("NTP synchronized")
        return self.warned("not NTP-synchronized yet (no time source "
                           "reachable?)")

    def check_timesyncd_dropin(self):
        """timesyncd-acadia.conf shipped via systemd bbappend."""
        r = self.run("find /etc/systemd -name 'timesyncd-acadia.conf' "
                     "2>/dev/null | head -1")
        path = r.stdout.strip()
        if path:
            return self.passed(path)
        return self.failed("timesyncd-acadia.conf missing")