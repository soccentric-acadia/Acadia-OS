"""FeatureSuite base class, check registry, and result types.

A suite is one feature area. Checks are methods named `check_*`, executed in
definition order. Adding a suite = adding a subclass; the runner discovers it.
"""

from __future__ import annotations

import inspect
import time
import traceback
from dataclasses import dataclass, field
from enum import Enum

from .connection import PrivilegeUnavailable


class Status(str, Enum):
    PASS = "PASS"
    FAIL = "FAIL"
    SKIP = "SKIP"
    WARN = "WARN"


@dataclass
class CheckResult:
    suite: str
    name: str
    status: Status
    detail: str = ""
    elapsed: float = 0.0


@dataclass
class SuiteResult:
    suite: str
    description: str
    groups: list
    results: list = None

    def __post_init__(self):
        self.results = self.results or []

    def counts(self) -> dict:
        c = {"PASS": 0, "FAIL": 0, "SKIP": 0, "WARN": 0}
        for r in self.results:
            c[r.status.value] += 1
        return c


class FeatureSuite:
    """Base class for a feature-area suite."""

    name: str = ""
    description: str = ""
    groups: tuple = ()
    boards: tuple = ()  # empty → applies to all machines

    def __init__(self, conn) -> None:
        self.conn = conn

    # ── discovery ────────────────────────────────────────────────────────
    def iter_checks(self) -> list:
        """check_* methods in definition order."""
        methods = []
        for cname, member in inspect.getmembers(self, inspect.ismethod):
            if cname.startswith("check_"):
                methods.append((inspect.getsourcelines(member)[1], member))
        return [m for _, m in sorted(methods, key=lambda x: x[0])]

    def count_lines(self, cmd: str, sudo: bool = False,
                    default: int = 0) -> int:
        """Run a counting command and parse its integer output safely."""
        r = self.run_priv(cmd) if sudo else self.run(cmd)
        if r is None:
            return default
        try:
            return int(r.stdout.strip() or "0")
        except ValueError:
            return default

    def applies_to_machine(self, machine: str) -> bool:
        if not self.boards:
            return True
        return any(machine.startswith(b) for b in self.boards)

    # ── result helpers ───────────────────────────────────────────────────
    @staticmethod
    def _result(name: str, status: Status, detail: str = "") -> CheckResult:
        return CheckResult(suite="", name=name, status=status, detail=detail)

    def passed(self, detail: str = "") -> CheckResult:
        return self._result(self._current_check, Status.PASS, detail)

    def failed(self, detail: str = "") -> CheckResult:
        return self._result(self._current_check, Status.FAIL, detail)

    def skipped(self, reason: str) -> CheckResult:
        return self._result(self._current_check, Status.SKIP, reason)

    def warned(self, detail: str) -> CheckResult:
        return self._result(self._current_check, Status.WARN, detail)

    # ── board helpers ────────────────────────────────────────────────────
    def machine(self) -> str:
        return self.conn.machine()

    def is_ab_board(self) -> bool:
        """Machines using the A/B WKS layout (pst + dual rootfs)."""
        return self.machine().startswith(("raspberrypi5", "raspberrypi-cm5"))

    def instrumentation_board(self) -> bool:
        return self.machine().startswith(
            ("raspberrypi4-64", "raspberrypi5", "raspberrypi-cm5"))

    # ── convenience wrappers ─────────────────────────────────────────────
    def run(self, cmd: str, timeout: float | None = None, sudo: bool = False):
        return self.conn.run(cmd, timeout=timeout, sudo=sudo)

    def run_priv(self, cmd: str, timeout: float | None = None):
        """Run with sudo; returns None when passwordless sudo is absent."""
        try:
            return self.run(cmd, timeout=timeout, sudo=True)
        except PrivilegeUnavailable:
            return None

    # ── systemd helpers ──────────────────────────────────────────────────
    def unit_state(self, unit: str) -> dict:
        """Type/ActiveState/UnitFileState/Result for one unit in one call."""
        r = self.run(f"systemctl show -p Type,ActiveState,SubState,"
                     f"UnitFileState,Result -- {unit} 2>/dev/null")
        state: dict = {}
        for line in r.stdout.splitlines():
            if "=" in line:
                k, _, v = line.partition("=")
                state[k.strip()] = v.strip()
        return state

    def expect_unit(self, unit: str, *, enabled: bool = True,
                    allow_inactive: bool = False) -> CheckResult:
        """Standard verdict for a promised unit.

        Long-running units must be active. Oneshot/early-boot units may be
        inactive provided they enabled and did not fail (they already ran).
        """
        st = self.unit_state(unit)
        active = st.get("ActiveState", "unknown")
        ufs = st.get("UnitFileState", "unknown")
        result = st.get("Result", "")
        utype = st.get("Type", "")
        detail = (f"type={utype or '?'} state={active} "
                  f"unit-file={ufs} result={result or 'n/a'}")
        problems = []
        if enabled and ufs == "disabled":
            problems.append(f"unit is disabled (SYSTEMD_AUTO_ENABLE=enable "
                            f"promised)")
        if active == "failed" or result == "exit-code":
            failed_res = self.run(f"systemctl status --no-pager -n 3 -- {unit} "
                                  f"2>/dev/null | tail -3")
            problems.append(f"unit failed: "
                            f"{failed_res.stdout.strip() or detail}")
        elif active != "active":
            ran_ok = allow_inactive and result in ("", "success") \
                and ufs == "enabled"
            if not ran_ok:
                problems.append(f"not active ({detail})")
        if problems:
            return self.failed("; ".join(problems))
        return self.passed(detail)

    def exists(self, path: str) -> bool:
        return self.conn.exists(path)

    def cat(self, path: str) -> str | None:
        return self.conn.cat(path)


def run_suite(suite: FeatureSuite) -> SuiteResult:
    """Execute all checks of a suite, isolating every failure per check."""
    result = SuiteResult(suite=suite.name, description=suite.description,
                         groups=list(suite.groups))
    machine = suite.machine()
    if not suite.applies_to_machine(machine):
        result.results.append(CheckResult(
            suite=suite.name, name="suite applicability", status=Status.SKIP,
            detail=f"board '{machine}' not in {suite.boards}"))
        return result
    for method in suite.iter_checks():
        name = method.__name__[6:].replace("_", " ")
        suite._current_check = name  # noqa: SLF001 — deliberate, same object
        start = time.monotonic()
        try:
            res = method()
            if not isinstance(res, CheckResult):
                res = CheckResult(suite=suite.name, name=name,
                                  status=Status.FAIL,
                                  detail=f"check returned {res!r}")
        except Exception as exc:  # noqa: BLE001 — isolate per check
            tb = traceback.format_exc(limit=2)
            res = CheckResult(suite=suite.name, name=name, status=Status.FAIL,
                              detail=f"exception: {exc}: {tb.splitlines()[-2]}")
        res.elapsed = round(time.monotonic() - start, 3)
        res.suite = suite.name
        res.name = name
        if getattr(suite.conn.cfg, "verbose", False):
            print(f"  [{suite.name}] {name}: {res.status.value} "
                  f"— {res.detail}", flush=True)
        result.results.append(res)
    return result