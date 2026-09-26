"""t04 — Promised systemd units.

Promise source: SYSTEMD_SERVICE in acadia-services, acadia-hardening,
acadia-data-init, acadia-device-identity, acadia-pst-init, rpi5-home-init,
acadia-factory-provision/wipe, acadia-boot-integrity, rpi5-swupdate-config,
watchdog (via 80-acadia-watchdog.preset).
"""

from acadia_validation.base import FeatureSuite

# Long-running daemons: must be active right now.
ALWAYS_ACTIVE = (
    "acadia-client.service",       # OS-028: IV&V gRPC agent
    "watchdog.service",            # watchdog pkg, enabled via preset
)

# Early-boot units: enabled + ran without failure is the contract
# (Type=oneshot by design; they go inactive after completing).
EARLY_UNITS = (
    "acadia-firewall.service",     # acadia-hardening (F01): applies rules
    "acadia-device-identity.service",
    "acadia-boot-integrity.service",
    "dmesg-capture.service",       # acadia-services (issue #56)
    "rtc-sync.service",
    "rtc-sync-shutdown.service",
    "acadia-data-init.service",
    "rpi5-home-init.service",
    "acadia-factory-wipe.service",
)

# A/B-board-only units (rpi5-swupdate-config, acadia-pst-init).
AB_ACTIVE = ("swupdate.service", "boot-watchdog.service")
AB_EARLY = ("acadia-pst-init.service", "acadia-factory-provision.service",
            "bootcount-reset.service", "swupdate-bootcheck.service")
AB_MOUNTS = ("pst.mount",)


class ServicesSuite(FeatureSuite):
    name = "services"
    description = "Promised systemd units: active, enabled, not failed"
    groups = ("core", "services")

    def check_daemon_services_active(self):
        results = []
        for unit in ALWAYS_ACTIVE:
            st = self.unit_state(unit)
            state = st.get("ActiveState", "missing")
            results.append(f"{unit}={state}")
            if state != "active":
                return self.failed("; ".join(results))
        return self.passed("; ".join(results))

    def check_swupdate_daemon_active(self):
        """swupdate install daemon + boot-watchdog keeper."""
        if not self.is_ab_board():
            return self.skipped("swupdate A/B units are rpi5/cm5-only")
        results = []
        for unit in AB_ACTIVE:
            st = self.unit_state(unit)
            if st.get("ActiveState") != "active":
                results.append(f"{unit}={st.get('ActiveState', 'missing')}"
                               f" ({st.get('Result', '?')})")
        if results:
            return self.failed("; ".join(results))
        return self.passed(f"{len(AB_ACTIVE)} daemon units active")

    def check_early_boot_units(self):
        """Early-boot units: enabled and not failed (they already ran)."""
        units = list(EARLY_UNITS)
        if self.is_ab_board():
            units += list(AB_EARLY)
        results = []
        for unit in units:
            res = self.expect_unit(unit, allow_inactive=True)
            if res.status.value == "FAIL":
                return self.failed(f"{unit}: {res.detail}")
            results.append(f"{unit.split('.')[0]}=ok")
        return self.passed(f"{len(units)} early-boot units healthy: "
                           + ", ".join(results))

    def check_pst_mount_unit(self):
        """pst.mount (LABEL=pst) — acadia-pst-init."""
        if not self.is_ab_board():
            return self.skipped("pst.mount is rpi5/cm5-only")
        return self.expect_unit("pst.mount")

    def check_health_timers_active(self):
        """thermal-check.timer + disk-usage-check.timer (acadia-services)."""
        results = []
        for timer in ("thermal-check.timer", "disk-usage-check.timer"):
            st = self.unit_state(timer)
            if st.get("ActiveState") != "active":
                results.append(f"{timer}={st.get('ActiveState', 'missing')}")
        if results:
            return self.failed("; ".join(results))
        nxt = self.run("systemctl list-timers thermal-check.timer "
                       "disk-usage-check.timer --no-legend 2>/dev/null "
                       "| head -2").stdout.strip().replace("\n", " | ")
        return self.passed(f"timers active; next: {nxt}")

    def check_watchdog_ready(self):
        """watchdog daemon + hardware node + acadia watchdog.conf."""
        problems = []
        if not self.exists("/dev/watchdog"):
            problems.append("/dev/watchdog missing (hardware node)")
        r = self.run("grep -q . /etc/watchdog.conf 2>/dev/null")
        if not r.ok:
            problems.append("/etc/watchdog.conf missing/empty "
                            "(acadia-services)")
        if problems:
            return self.failed("; ".join(problems))
        timeout = self.run("grep -E '^watchdog-timeout' /etc/watchdog.conf "
                           "2>/dev/null | head -1").stdout.strip()
        return self.passed(f"/dev/watchdog + config present"
                           + (f" ({timeout})" if timeout else ""))

    def check_rsyslog_active(self):
        """T-P29: remote syslog transport for WebConfig."""
        st = self.unit_state("rsyslog.service")
        if st.get("ActiveState") != "active":
            return self.failed(f"rsyslog {st.get('ActiveState', 'missing')}")
        return self.passed("rsyslog.service active")