"""t09 — OTA / A-B readiness (non-destructive).

Promise source: rpi5-swupdate-config (bootcheck, boot-watchdog,
bootcount-reset, tryboot flow, inactive-slot /dev contract), swupdate
daemon + client. Destructive install/rollback is scripts/hil-ota.sh.
"""

from acadia_validation.base import FeatureSuite


class OtaAbSuite(FeatureSuite):
    name = "ota-ab"
    description = "swupdate readiness: daemon, keys, boot files, slots"
    groups = ("ota", "core")
    boards = ("raspberrypi5", "raspberrypi-cm5")

    def check_config_and_keys(self):
        """/etc/swupdate/swupdate.cfg + swupdate-public.pem shipped."""
        r = self.run("test -e /etc/swupdate/swupdate.cfg && echo cfg || true; "
                     "find /usr/lib/swupdate /etc/swupdate -maxdepth 1 "
                     "-name 'swupdate-public.pem' 2>/dev/null | head -1")
        out = r.stdout.strip().splitlines()
        has_cfg = any("cfg" in l for l in out)
        pem = next((l for l in out if l.endswith(".pem")), "")
        problems = []
        if not has_cfg:
            problems.append("/etc/swupdate/swupdate.cfg missing")
        if not pem:
            problems.append("swupdate-public.pem missing")
        if problems:
            return self.failed("; ".join(problems))
        return self.passed(f"swupdate.cfg + {pem}")

    def check_inactive_slot_contract(self):
        """/dev/swupdate-inactive — the rpi5-swupdate-config contract."""
        r = self.run("test -e /dev/swupdate-inactive && ls -l "
                     "/dev/swupdate-inactive 2>/dev/null | head -1")
        if r.ok:
            return self.passed(f"/dev/swupdate-inactive present")
        return self.failed("/dev/swupdate-inactive missing "
                           "(inactive-slot contract broken)")

    def check_boot_files(self):
        """/boot/config.txt + tryboot.txt (tryboot flow) + fw_env.config."""
        problems = []
        if not self.exists("/boot/config.txt"):
            problems.append("/boot/config.txt missing")
        if not self.exists("/boot/tryboot.txt"):
            problems.append("/boot/tryboot.txt missing (tryboot flow)")
        if not self.exists("/etc/fw_env.config"):
            problems.append("/etc/fw_env.config missing")
        if problems:
            return self.failed("; ".join(problems))
        return self.passed("config.txt, tryboot.txt, fw_env.config present")

    def check_swupdate_scripts(self):
        """pre/post-install, reboot-tryboot, bootcheck, start wrapper."""
        r = self.run("for s in pre-install.sh post-install.sh "
                     "reboot-tryboot.sh swupdate-bootcheck.sh "
                     "swupdate-start.sh; do "
                     "find /usr/lib/swupdate -name \"$s\" 2>/dev/null "
                     "| grep -q . || echo \"missing:$s\"; done")
        missing = [l.split(":", 1)[1] for l in r.stdout.splitlines()
                   if l.startswith("missing:")]
        if missing:
            return self.failed(f"missing scripts: {', '.join(missing)}")
        return self.passed("all swupdate helper scripts installed")

    def check_current_slot(self):
        """Informational: which A/B slot is currently running."""
        r = self.run("findmnt -n -o SOURCE / 2>/dev/null")
        src = r.stdout.strip()
        if not src:
            return self.skipped("no rootfs source resolved")
        tail = src.rsplit("p", 1)[-1]
        slot = "A" if tail == "2" else ("B" if tail == "3" else f"p{tail}")
        return self.passed(f"running slot {slot} ({src})")

    def check_ota_helpers_ready(self):
        """swupdate-client (T-P26) hands bundles to the daemon."""
        r = self.run("command -v swupdate-client && "
                     "grep -q . /etc/swupdate/swupdate.cfg 2>/dev/null "
                     "&& echo ok")
        if r.ok:
            return self.passed("swupdate-client + config ready")
        return self.failed("swupdate-client or config incomplete")