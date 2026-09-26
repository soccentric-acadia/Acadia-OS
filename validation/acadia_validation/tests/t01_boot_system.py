"""t01 — Boot & system identity.

Promises (meta-acadia): /etc/os-release identifies "Acadia OS"; PREEMPT_RT
kernel (task 002); systemd boots clean; no critical kernel errors.
"""

from acadia_validation.base import FeatureSuite


class BootSystemSuite(FeatureSuite):
    name = "boot-system"
    description = "OS identity, PREEMPT_RT kernel, clean systemd boot"
    groups = ("core", "boot")

    def check_os_release_identity(self):
        """os-release.bbappend (T052): ID=acadia, NAME="Acadia OS"."""
        osr = self.conn.os_release()
        problems = []
        if osr.get("ID") != "acadia":
            problems.append(f"ID={osr.get('ID')!r} (expected 'acadia')")
        if "Acadia OS" not in osr.get("NAME", ""):
            problems.append(f"NAME={osr.get('NAME')!r}")
        if "Acadia OS" not in osr.get("PRETTY_NAME", ""):
            problems.append(f"PRETTY_NAME={osr.get('PRETTY_NAME')!r}")
        if problems:
            return self.failed("; ".join(problems))
        return self.passed(f"PRETTY_NAME={osr.get('PRETTY_NAME', '?')}")

    def check_build_pairing(self):
        """Booted image pairs with the manifest (see
        tools/generate-manifest.sh): machine + VERSION_ID."""
        from acadia_validation.manifest import pairing_problems
        manifest = getattr(self.conn, "manifest", None)
        if not manifest:
            return self.skipped("no --manifest given "
                                "(generate with tools/generate-manifest.sh)")
        problems = pairing_problems(manifest, self.conn.os_release(),
                                    self.machine(), self.conn.model())
        if problems:
            return self.failed("; ".join(problems))
        return self.passed(f"target pairs with build "
                           f"{manifest.get('build_id', '?')} "
                           f"(version {manifest.get('version_id', '?')})")

    def check_boot_model(self):
        """/proc/device-tree/model — board the image is running on."""
        model = self.conn.model()
        if not model:
            return self.failed("/proc/device-tree/model unreadable")
        return self.passed(f"{model} (machine={self.machine()})")

    def check_kernel_realtime(self):
        """task 002: PREEMPT_RT kernel."""
        r = self.run("uname -rv")
        kernel = r.stdout.strip()
        if "PREEMPT_RT" in kernel:
            return self.passed(kernel)
        return self.failed(f"no PREEMPT_RT in: {kernel}")

    def check_kernel_cmdline(self):
        """/proc/cmdline names the root device (boot chain reached Linux)."""
        r = self.run("cat /proc/cmdline")
        cmdline = r.stdout.strip()
        if "root=" in cmdline:
            return self.passed(cmdline[:120])
        return self.failed(f"cmdline lacks root=: {cmdline!r}")

    def check_systemd_failed_units(self):
        """A clean boot must leave zero failed units."""
        r = self.run("systemctl --failed --no-legend --plain 2>/dev/null "
                     "| grep -c . || true")
        count = r.stdout.strip() or "0"
        if count == "0":
            return self.passed("no failed units")
        listing = self.run("systemctl --failed --no-legend --plain 2>/dev/null"
                           " | head -5").stdout.strip()
        return self.failed(f"{count} failed units: {listing}")

    def check_kernel_critical_errors(self):
        """dmesg must be free of emerg/alert/crit lines."""
        r = self.run_priv("dmesg --notime --level=emerg,alert,crit "
                          "| grep -c . || true")
        if r is None:
            return self.skipped("dmesg needs root and no passwordless sudo")
        count = (r.stdout.strip() or "0")
        if count == "0":
            return self.passed("no emerg/alert/crit kernel messages")
        first = self.run_priv("dmesg --notime --level=emerg,alert,crit "
                              "| head -3")
        return self.failed(f"{count} critical kernel messages: "
                           f"{(first.stdout.strip() if first else '')[:200]}")

    def check_kernel_errors_warn(self):
        """Plain err-level kernel messages are noteworthy, not fatal."""
        r = self.run_priv("dmesg --notime --level=err | grep -c . || true")
        if r is None:
            return self.skipped("dmesg needs root and no passwordless sudo")
        count = r.stdout.strip() or "0"
        if count == "0":
            return self.passed("no err-level kernel messages")
        return self.warned(f"{count} err-level kernel messages present")