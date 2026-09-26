"""Report assembly: counts, console table, Markdown, JSON, exit codes."""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass, field, asdict


def _use_color() -> bool:
    return sys.stdout.isatty()


def _paint(status: str, text: str) -> str:
    if not _use_color():
        return text
    colors = {"PASS": "\033[32m", "FAIL": "\033[31m", "SKIP": "\033[33m",
              "WARN": "\033[35m"}
    return f"{colors.get(status, '')}{text}\033[0m"


@dataclass
class Report:
    started: str
    host: str
    user: str
    model: str
    machine: str
    strict: bool
    allow_password_ssh: bool
    suites: list = field(default_factory=list)
    total_elapsed: float = 0.0

    # ── aggregation ──────────────────────────────────────────────────────
    def counts(self) -> dict:
        c = {"PASS": 0, "FAIL": 0, "SKIP": 0, "WARN": 0}
        for s in self.suites:
            for k, v in s.counts().items():
                c[k] += v
        return c

    def exit_code(self) -> int:
        c = self.counts()
        if c["FAIL"]:
            return 1
        if self.strict and c["SKIP"]:
            return 1
        return 0

    # ── console ──────────────────────────────────────────────────────────
    def print_console(self) -> None:
        print(f"\n=== Acadia validation — {self.host} "
              f"(model: {self.model or 'n/a'}, machine: {self.machine}) ===\n")
        for s in self.suites:
            c = s.counts()
            head = (f"[{s.suite}] {s.description}"
                    f"  ({c['PASS']}P/{c['FAIL']}F/{c['SKIP']}S/{c['WARN']}W)")
            print(_paint("PASS", "── ") + head)
            for r in s.results:
                mark = _paint(r.status.value, f"{r.status.value:4}")
                line = f"  {mark}  {r.name}"
                if r.detail:
                    line += f" — {r.detail}"
                print(line)
        c = self.counts()
        print(f"\nSummary: {c['PASS']} passed, {c['FAIL']} failed, "
              f"{c['SKIP']} skipped, {c['WARN']} warned "
              f"in {self.total_elapsed:.1f}s")
        if c["WARN"]:
            print("Note: WARN = check passed with a noteworthy observation.")
        if c["SKIP"]:
            print("Note: SKIP = not applicable here (see reasons). "
                  + ("Strict mode treats SKIP as failure."
                     if self.strict else "Use --strict for CI."))

    # ── formats ──────────────────────────────────────────────────────────
    def to_json(self) -> str:
        return json.dumps(asdict(self), indent=2, default=str)

    def to_markdown(self) -> str:
        lines = [
            "# Acadia validation report",
            "",
            f"- **Target:** {self.host} (user `{self.user}`)",
            f"- **Model:** {self.model} · machine `{self.machine}`",
            f"- **Started:** {self.started} · elapsed {self.total_elapsed:.1f}s",
            f"- **Mode:** strict={self.strict}, "
            f"allow_password_ssh={self.allow_password_ssh}",
            "",
            "| Suite | Check | Status | Detail | s |",
            "|---|---|---|---|---|",
        ]
        for s in self.suites:
            for r in s.results:
                detail = (r.detail or "").replace("|", "\\|").replace("\n", " ")
                lines.append(
                    f"| {s.suite} | {r.name} | {r.status.value} "
                    f"| {detail} | {r.elapsed} |")
        c = self.counts()
        lines += ["", f"**Totals:** {c['PASS']} PASS · {c['FAIL']} FAIL · "
                      f"{c['SKIP']} SKIP · {c['WARN']} WARN"]
        return "\n".join(lines) + "\n"