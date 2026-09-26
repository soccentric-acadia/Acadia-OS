"""CLI: argument parsing, credential resolution, fleet mode, report persistence."""

from __future__ import annotations

import argparse
import getpass
import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path

from .config import TargetConfig
from .results import Report, _paint

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
    sel.add_argument("--trace", action="store_true",
                     help="with --list: print each check's promise reference")
    sel.add_argument("--inventory", default=None,
                     help="fleet mode: file with 'host user password [port]' "
                          "per line")
    sel.add_argument("--parallel", type=int, default=1,
                     help="parallel targets in fleet mode")
    pairing = p.add_argument_group("pairing & budgets")
    pairing.add_argument("--manifest", dest="manifest_path", default=None,
                         help="build manifest JSON (see tools/generate-manifest.sh)")
    pairing.add_argument("--boot-budget", type=float, default=180.0,
                         help="boot-to-userspace budget in seconds")
    pairing.add_argument("--latency-budget", type=int, default=1000,
                         help="cyclictest Avg latency budget in µs")
    api = p.add_argument_group("webconfig api (optional)")
    api.add_argument("--webconfig-user", default=None)
    api.add_argument("--webconfig-pass", default=None)
    mode = p.add_argument_group("mode")
    mode.add_argument("--strict", action="store_true",
                      help="SKIP counts as failure (CI)")
    mode.add_argument("--allow-password-ssh", action="store_true",
                      help="downgrade sshd password-policy mismatch to WARN")
    mode.add_argument("--verbose", action="store_true",
                      help="print each check result as it runs")
    out = p.add_argument_group("output")
    out.add_argument("--report-dir", default=None,
                     help="override report output directory")
    out.add_argument("--no-reports", action="store_true",
                     help="do not write report files")
    out.add_argument("--diff", nargs=2, metavar=("A.json", "B.json"),
                     help="compare two reports; exit 1 on regressions")
    return p


def list_suites(trace: bool = False) -> int:
    import importlib
    import inspect
    tests_pkg = importlib.import_module(TESTS_PKG)
    from .runner import discover_suites

    print(f"{'suite':34} {'groups':36} {'checks':6} description")
    all_groups: set[str] = set()
    for cls in discover_suites(tests_pkg):
        checks = [m for n, m in inspect.getmembers(cls, inspect.isfunction)
                  if n.startswith("check_")]
        groups = ",".join(cls.groups)
        all_groups.update(cls.groups)
        print(f"{cls.name or cls.__name__:34} {groups:36} "
              f"{len(checks):6}  {cls.description}")
        if trace:
            for name, member in sorted(
                    inspect.getmembers(cls, inspect.isfunction)):
                if not name.startswith("check_"):
                    continue
                doc = (inspect.getdoc(member) or "").splitlines()
                promise = doc[0].strip() if doc else "(no promise note)"
                print(f"    {'':32} └─ {name[6:]:36} promise: {promise}")
    print(f"\ngroups: {', '.join(sorted(all_groups))}")
    return 0


def _resolve_credentials(args, cfg) -> None:
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


def _diff_reports(a_path: str, b_path: str) -> int:
    """Status changes between two report JSONs; regression → exit 1."""
    import json

    def index(path):
        data = json.loads(Path(path).read_text())
        out = {}
        for s in data["suites"]:
            for r in s["results"]:
                out[(s["suite"], r["name"])] = r["status"]
        return out

    a, b = index(a_path), index(b_path)
    regressions = []
    for k in sorted(set(a) | set(b)):
        sa, sb = a.get(k), b.get(k)
        if sa == sb:
            continue
        rank = {"PASS": 0, "WARN": 1, "SKIP": 2, "FAIL": 3, None: 3}
        mark = "REGRESSION" if rank.get(sb, 3) > rank.get(sa or "PASS", 0) \
            else "changed"
        line = f"[{k[0]}] {k[1]}: {sa} → {sb} ({mark})"
        print(("  " + _paint("FAIL", line)) if mark == "REGRESSION"
              else ("  " + line))
        if mark == "REGRESSION":
            regressions.append(k)
    print(f"\ndiff: {len(set(a) & set(b))} checks compared, "
          f"{len(regressions)} regression(s), "
          f"{len(set(a) - set(b))} only-in-A, "
          f"{len(set(b) - set(a))} only-in-B")
    return 1 if regressions else 0


def _suite_for_entry(entry: dict, base_args, base_cfg_kwargs) -> Report:
    """Run one inventory entry (used by fleet mode)."""
    import importlib
    from .connection import TargetConnection, TargetUnreachable
    from .runner import run_all

    cfg = type(base_cfg_kwargs["cfg_proto"])(**{k: v for k, v in
                                                base_cfg_kwargs.items()
                                                if k != "cfg_proto"})
    conn = TargetConnection(cfg)
    try:
        conn.connect()
    except (TargetUnreachable, ModuleNotFoundError) as exc:
        r = Report(started="", host=cfg.host, user=cfg.user, model="",
                   machine="unreachable", strict=False,
                   allow_password_ssh=False)
        r.error = str(exc)
        return r
    try:
        return run_all(conn, cfg, importlib.import_module(TESTS_PKG),
                       include_groups=base_args.groups,
                       exclude_groups=base_args.exclude_groups,
                       only=base_args.only)
    finally:
        conn.close()


def main(argv=None) -> int:
    args = _parser().parse_args(argv)

    if args.diff:
        return _diff_reports(args.diff[0], args.diff[1])
    if args.list:
        return list_suites(trace=args.trace)

    import importlib
    tests_pkg = importlib.import_module(TESTS_PKG)

    from .connection import TargetConnection, TargetUnreachable
    from .runner import run_all

    cfg = TargetConfig(
        host=args.host, port=args.port, user=args.user, password=args.password,
        key_file=args.key_file, connect_timeout=args.connect_timeout,
        exec_timeout=args.timeout, strict=args.strict,
        allow_password_ssh=args.allow_password_ssh,
        manifest_path=args.manifest_path,
        boot_budget=args.boot_budget, latency_budget=args.latency_budget,
        webconfig_user=args.webconfig_user, webconfig_pass=args.webconfig_pass,
        verbose=args.verbose)

    manifest = None
    if cfg.manifest_path:
        from .manifest import load_manifest
        manifest = load_manifest(cfg.manifest_path)
        if manifest is None:
            print(f"error: manifest not found: {cfg.manifest_path}",
                  file=sys.stderr)
            return 2
        print(f"manifest loaded: machine={manifest.get('machine')} "
              f"version={manifest.get('version_id')} "
              f"packages={manifest.get('package_count')}")

    if args.inventory:
        return _run_fleet(args, cfg, tests_pkg)

    _resolve_credentials(args, cfg)
    conn = TargetConnection(cfg)
    conn.manifest = manifest
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
        from datetime import datetime as dt
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        base = report_dir / f"report-{stamp}-{cfg.host}"
        base.with_suffix(".json").write_text(report.to_json())
        base.with_suffix(".md").write_text(report.to_markdown())
        print(f"reports: {base}.json, {base}.md")

    return report.exit_code()


def _run_fleet(args, cfg, tests_pkg) -> int:
    """Fleet mode: one line per target: `host user password [key]`."""
    from .connection import TargetConnection, TargetUnreachable
    from .manifest import load_manifest
    from .runner import run_all

    inventory = Path(args.inventory)
    entries = []
    for raw in inventory.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 3:
            print(f"error: inventory line needs 'host user password': "
                  f"{raw!r}", file=sys.stderr)
            return 2
        entries.append(parts)

    manifest = None
    if cfg.manifest_path:
        manifest = load_manifest(cfg.manifest_path)

    def one(parts):
        host, user, password = parts[0], parts[1], parts[2]
        key = parts[3] if len(parts) > 3 else None
        c = TargetConfig(
            host=host, port=args.port, user=user, password=password,
            key_file=key, connect_timeout=cfg.connect_timeout,
            exec_timeout=cfg.exec_timeout, strict=cfg.strict,
            allow_password_ssh=cfg.allow_password_ssh,
            manifest_path=cfg.manifest_path,
            boot_budget=cfg.boot_budget, latency_budget=cfg.latency_budget,
            webconfig_user=cfg.webconfig_user,
            webconfig_pass=cfg.webconfig_pass)
        conn = TargetConnection(c)
        conn.manifest = manifest
        try:
            conn.connect()
        except (TargetUnreachable, ModuleNotFoundError) as exc:
            r = Report(started="", host=host, user=user, model="",
                       machine="unreachable", strict=c.strict,
                       allow_password_ssh=c.allow_password_ssh)
            r.error = str(exc)
            return r
        try:
            return run_all(conn, c, tests_pkg,
                           include_groups=args.groups,
                           exclude_groups=args.exclude_groups,
                           only=args.only)
        finally:
            conn.close()

    workers = max(1, args.parallel)
    reports = []
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(one, e): e[0] for e in entries}
        for fut in as_completed(futures):
            r = fut.result()
            reports.append(r)
            c = r.counts()
            err = getattr(r, "error", None)
            print(_paint("FAIL", f"  ✗ {r.host}") if c["FAIL"] or err
                  else _paint("PASS", f"  ✓ {r.host}")
                  + f"  ({c['PASS']}P/{c['FAIL']}F/{c['SKIP']}S"
                    f"/{c['WARN']}W"
                    + (f" — {err}" if err else "")
                  + ")")

    reports.sort(key=lambda r: r.host)
    total_fail = sum(r.counts()["FAIL"] for r in reports)
    unreachable = sum(1 for r in reports if getattr(r, "error", None))
    print(f"\nFleet: {len(reports)} targets — {total_fail} total failures, "
          f"{unreachable} unreachable")

    if not args.no_reports:
        report_dir = Path(args.report_dir or Path(__file__).resolve()
                          .parent.parent / "reports")
        report_dir.mkdir(parents=True, exist_ok=True)
        from datetime import datetime
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        base = report_dir / f"fleet-{stamp}"
        import json as _json
        base.with_suffix(".json").write_text(
            _json.dumps([_json.loads(r.to_json()) for r in reports],
                        indent=2, default=str))
        print(f"report: {base}.json")

    return 1 if (total_fail or unreachable) else 0


if __name__ == "__main__":
    raise SystemExit(main())