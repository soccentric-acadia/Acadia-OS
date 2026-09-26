"""CLI: argument parsing, credential resolution, report persistence."""

from __future__ import annotations

import argparse
import getpass
import sys
from datetime import datetime
from pathlib import Path

from .config import TargetConfig
from .results import Report

TESTS_PKG = "acadia_validation.tests"


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="acadia-validation",
        description="Post-boot feature validation for Acadia-OS images "
                    "(host-driven, SSH).")
    tgt = p.add_argument_group("target")
    tgt.add_argument("--host", help="target IP/hostname "
                                    "(env VALIDATION_HOST)")
    tgt.add_argument("--port", type=int, default=22)
    tgt.add_argument("--user", default="rpi")
    tgt.add_argument("--password", help="SSH password (env VALIDATION_PASSWORD)")
    tgt.add_argument("--key", dest="key_file", help="SSH private key file")
    tgt.add_argument("--connect-timeout", type=float, default=15.0)
    tgt.add_argument("--timeout", type=float, default=60.0,
                     help="per-command timeout (s)")
    sel = p.add_argument_group("selection")
    sel.add_argument("--groups", default="",
                     help="comma list of groups to include (default: all)")
    sel.add_argument("--exclude-groups", default="")
    sel.add_argument("--only", default="",
                     help="comma list of suite names/prefixes (e.g. t01,services)")
    sel.add_argument("--list", action="store_true",
                     help="list suites and exit (no target needed)")
    mode = p.add_argument_group("mode")
    mode.add_argument("--strict", action="store_true",
                      help="SKIP counts as failure (CI)")
    mode.add_argument("--allow-password-ssh", action="store_true",
                      help="downgrade sshd password-policy mismatch to WARN")
    out = p.add_argument_group("output")
    out.add_argument("--report-dir", default=None,
                     help="override report output directory")
    out.add_argument("--no-reports", action="store_true",
                     help="do not write report files")
    return p


def list_suites() -> int:
    import importlib
    tests_pkg = importlib.import_module(TESTS_PKG)
    from .runner import discover_suites

    print(f"{'suite':34} {'groups':36} checks  description")
    all_groups: set[str] = set()
    for cls in discover_suites(tests_pkg):
        import inspect
        checks = [m for n, m in inspect.getmembers(cls, inspect.isfunction)
                  if n.startswith("check_")]
        groups = ",".join(cls.groups)
        all_groups.update(cls.groups)
        print(f"{cls.name or cls.__name__:34} {groups:36} "
              f"{len(checks):6}  {cls.description}")
    print(f"\ngroups: {', '.join(sorted(all_groups))}")
    return 0


def _resolve_credentials(args, cfg: TargetConfig) -> None:
    env = TargetConfig.from_env()
    cfg.host = cfg.host or env["host"]
    cfg.user = env["user"] if cfg.user == "rpi" and env["user"] else cfg.user
    cfg.password = cfg.password or env["password"]
    cfg.key_file = cfg.key_file or env["key_file"]
    if not cfg.host:
        print("error: no target — pass --host or set VALIDATION_HOST",
              file=sys.stderr)
        raise SystemExit(2)
    if not cfg.password and not cfg.key_file:
        cfg.password = getpass.getpass(
            f"SSH password for {cfg.user}@{cfg.host}: ")


def main(argv=None) -> int:
    args = _parser().parse_args(argv)
    if args.list:
        return list_suites()

    cfg = TargetConfig(
        host=args.host, port=args.port, user=args.user, password=args.password,
        key_file=args.key_file, connect_timeout=args.connect_timeout,
        exec_timeout=args.timeout, strict=args.strict,
        allow_password_ssh=args.allow_password_ssh)
    _resolve_credentials(args, cfg)

    import importlib
    tests_pkg = importlib.import_module(TESTS_PKG)

    from .connection import TargetConnection, TargetUnreachable
    from .runner import run_all

    conn = TargetConnection(cfg)
    try:
        conn.connect()
    except ModuleNotFoundError as exc:
        if "paramiko" in str(exc):
            print("error: paramiko not installed — run 'make setup' "
                  "in the validation folder (or: pip install paramiko)",
                  file=sys.stderr)
            return 2
        raise
    except TargetUnreachable as exc:
        print(f"CONNECTION FAILURE: {exc}", file=sys.stderr)
        print("The booted image did not present SSH — verify the device is "
              "flashed, powered, networked, and the SSH policy permits "
              "the chosen auth method.", file=sys.stderr)
        return 2

    try:
        report = run_all(conn, cfg, tests_pkg,
                         include_groups=args.groups,
                         exclude_groups=args.exclude_groups,
                         only=args.only)
    finally:
        conn.close()

    report.print_console()

    if not args.no_reports:
        report_dir = Path(args.report_dir or Path(__file__).resolve()
                          .parent.parent / "reports")
        report_dir.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        base = report_dir / f"report-{stamp}-{cfg.host}"
        (base.with_suffix(".json")).write_text(report.to_json())
        (base.with_suffix(".md")).write_text(report.to_markdown())
        print(f"reports: {base}.json, {base}.md")

    return report.exit_code()


if __name__ == "__main__":
    raise SystemExit(main())