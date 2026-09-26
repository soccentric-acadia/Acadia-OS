"""t15 — Real-time diagnostics & boot-time budget.

Promises: PREEMPT_RT kernel (task 002) should *measure* like it: bounded
scheduling latency (rt-tests/cyclictest, the reason it ships) and a sane
boot-to-userspace time (systemd-analyze).
"""

from acadia_validation.base import FeatureSuite


class RtDiagnosticsSuite(FeatureSuite):
    name = "rt-diagnostics"
    description = "Boot-time budget + cyclictest scheduling latency"
    groups = ("rt", "core", "boot")

    def check_boot_time(self):
        """systemd-analyze: kernel+userspace within --boot-budget (180s)."""
        r = self.run("systemd-analyze 2>/dev/null | head -1")
        line = r.stdout.strip()
        if not line:
            return self.skipped("systemd-analyze unavailable")
        import re
        m = re.search(r"=\s*([\d.]+)(ms|s|min)\s*$", line)
        if not m:
            return self.warned(f"unparsable: {line[:100]}")
        value, unit = float(m.group(1)), m.group(2)
        seconds = value if unit == "s" else value / 60 if unit == "min" \
            else value / 1000
        budget = self.conn.cfg.boot_budget
        if seconds <= budget:
            return self.passed(f"{line} (budget {budget:.0f}s)")
        return self.failed(f"{line} exceeds --boot-budget {budget:.0f}s")

    def check_scheduling_latency(self):
        """10 s cyclictest run; Avg latency within --latency-budget (µs).
        Uses rt-tests (task 002); needs root for -m (FIFO/memlock)."""
        r = self.run("command -v cyclictest")
        if not r.ok:
            return self.failed("cyclictest missing (rt-tests)")
        run = self.run_priv("cyclictest -m -D 10s -i 1000 -q 2>&1 | tail -1",
                            timeout=60)
        if run is None:
            return self.skipped("cyclictest needs root (-m) and no "
                                "passwordless sudo")
        import re
        line = run.stdout.strip()
        avg = re.search(r"Avg:\s*(\d+)", line)
        maximum = re.search(r"Max:\s*(\d+)", line)
        if not avg:
            return self.warned(f"cyclictest output unparsable: "
                               f"{line[:120]}")
        budget = self.conn.cfg.latency_budget
        avg_us = int(avg.group(1))
        max_us = int(maximum.group(1)) if maximum else -1
        detail = f"Avg {avg_us}µs" + (f", Max {max_us}µs" if max_us >= 0 else "")
        if avg_us <= budget:
            return self.passed(f"within --latency-budget {budget}µs: "
                               f"{detail}")
        return self.failed(f"Avg {avg_us}µs exceeds "
                           f"--latency-budget {budget}µs "
                           f"(Max {max_us}µs)")