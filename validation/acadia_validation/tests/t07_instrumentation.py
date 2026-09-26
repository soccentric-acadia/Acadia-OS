"""t07 — Instrumentation (istate hub + spokes).

Promise source: recipes-instrumentation/instrumentation. 9 spokes + istate
+ software watchdog; instr-ota ships but stays disabled (T-P00c).
Applies to raspberrypi4-64, raspberrypi5, raspberrypi-cm5 only.
"""

from acadia_validation.base import FeatureSuite

SPOKES = ("instr-networkd.service", "instr-monitord.service",
          "instr-hardware.service", "instr-faults.service",
          "instr-alarms.service", "instr-logmanager.service",
          "instr-telemetry.service", "instr-backup.service")
CTRL_TOOLS = ("istate_ctrl", "network_ctrl", "monitor_ctrl",
              "hardware_ctrl", "fault_ctrl", "alarm_ctrl")


class InstrumentationSuite(FeatureSuite):
    name = "instrumentation"
    description = "instr-istate hub, eight spokes, istate watchdog"
    groups = ("instrumentation", "middleware")
    boards = ("raspberrypi4-64", "raspberrypi5", "raspberrypi-cm5")

    def check_istate_hub_active(self):
        return self.expect_unit("instr-istate.service")

    def check_spokes_active(self):
        results = []
        for unit in SPOKES:
            st = self.unit_state(unit)
            if st.get("ActiveState") != "active":
                results.append(f"{unit}={st.get('ActiveState', 'missing')}")
        if results:
            return self.failed(f"{len(results)}/{len(SPOKES)} spokes down: "
                               + "; ".join(results))
        return self.passed(f"all {len(SPOKES)} spokes active")

    def check_istate_watchdog_active(self):
        res = self.expect_unit("instr-istate-watchdog.service")
        if res.status.value == "FAIL":
            return res
        tool = self.run("command -v instr-istate-watchdog")
        if not tool.ok:
            return self.failed("instr-istate-watchdog binary missing")
        return self.passed(f"{res.detail}; tool={tool.stdout.strip()}")

    def check_ota_spoke_shipped_disabled(self):
        """T-P00c: instr-ota ships (relay-addressable) but stays disabled."""
        r = self.run("systemctl list-unit-files instr-ota.service "
                     "--no-legend 2>/dev/null | head -1")
        if not r.stdout.strip():
            return self.failed("instr-ota unit file missing "
                               "(should ship disabled)")
        st = self.unit_state("instr-ota.service")
        if st.get("UnitFileState") == "disabled":
            return self.passed("instr-ota shipped and correctly disabled")
        return self.failed(f"instr-ota {st.get('UnitFileState', 'unknown')} "
                           "(must stay disabled)")

    def check_ctrl_tools(self):
        bins = " ".join(CTRL_TOOLS)
        r = self.run(f"for b in {bins}; do command -v \"$b\" >/dev/null 2>&1 "
                     f"|| echo \"missing:$b\"; done")
        missing = [l.split(":", 1)[1] for l in r.stdout.splitlines()
                   if l.startswith("missing:")]
        if missing:
            return self.failed(f"{len(missing)} ctrl tools missing: "
                               + ", ".join(missing))
        return self.passed(f"{len(CTRL_TOOLS)} *_ctrl tools present")

    def check_istate_journal_activity(self):
        """The hub must have produced at least one journal line."""
        r = self.run("journalctl -u instr-istate.service -n 1 --no-pager "
                     "2>/dev/null | grep -c . || true")
        count = r.stdout.strip() or "0"
        if count != "0":
            return self.passed("instr-istate journal evidence present")
        return self.warned("no instr-istate journal lines (spoke quiet?)")