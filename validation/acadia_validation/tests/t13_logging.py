"""t13 — Logging & diagnostics.

Promises: persistent journal (/var/log/journal — journald-acadia.conf),
rsyslog (T-P29), dmesg-capture into the journal (issue #56).
"""

from acadia_validation.base import FeatureSuite


class LoggingSuite(FeatureSuite):
    name = "logging"
    description = "Persistent journal, rsyslog, dmesg capture"
    groups = ("logging", "core")

    def check_persistent_journal(self):
        """/var/log/journal/<machine-id> must exist (journald-acadia.conf)."""
        r = self.run("test -d /var/log/journal && ls /var/log/journal/ "
                     "| grep -c . || true")
        count = r.stdout.strip() or "0"
        if count != "0":
            return self.passed(f"persistent journal ({count} machine dir(s))")
        return self.failed("/var/log/journal empty or missing "
                           "(journal is volatile)")

    def check_journald_dropin(self):
        r = self.run("find /etc/systemd -name 'journald-acadia.conf' "
                     "2>/dev/null | head -1")
        path = r.stdout.strip()
        if path:
            return self.passed(path)
        return self.failed("journald-acadia.conf missing")

    def check_rsyslog_active(self):
        st = self.unit_state("rsyslog.service")
        if st.get("ActiveState") == "active":
            logs = self.run("ls /var/log/messages /var/log/syslog 2>/dev/null "
                            "| head -1").stdout.strip()
            return self.passed(f"rsyslog active"
                               + (f", log evidence: {logs}" if logs else ""))
        return self.failed(f"rsyslog {st.get('ActiveState', 'missing')}")

    def check_dmesg_capture(self):
        """dmesg-capture.service: boot ring buffer → journal (dmesg-boot tag)."""
        res = self.expect_unit("dmesg-capture.service", allow_inactive=True)
        if res.status.value == "FAIL":
            return res
        r = self.run("journalctl -t dmesg-boot -n 1 --no-pager 2>/dev/null "
                     "| grep -c . || true")
        if (r.stdout.strip() or "0") != "0":
            return self.passed(f"{res.detail}; dmesg-boot captured")
        return self.warned("unit healthy but no dmesg-boot journal entries")

    def check_journalctl_functional(self):
        r = self.run("journalctl --disk-usage 2>/dev/null")
        if r.ok and r.stdout.strip():
            return self.passed(r.stdout.strip().splitlines()[0])
        return self.failed("journalctl --disk-usage failed")