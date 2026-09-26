"""Suite discovery, filtering, and execution."""

from __future__ import annotations

from datetime import datetime

from .base import FeatureSuite, run_suite
from .results import Report


def discover_suites(tests_pkg) -> list:
    """Import every module in tests/ and collect FeatureSuite subclasses.

    Module file order (t01_, t02_, …) gives a stable, readable run order.
    """
    import importlib
    import pkgutil

    classes: list[type[FeatureSuite]] = []
    for mod_info in sorted(pkgutil.iter_modules(tests_pkg.__path__),
                           key=lambda m: m.name):
        module = importlib.import_module(f"{tests_pkg.__name__}.{mod_info.name}")
        for attr in vars(module).values():
            if (isinstance(attr, type) and issubclass(attr, FeatureSuite)
                    and attr is not FeatureSuite
                    and attr.__module__ == module.__name__):
                classes.append(attr)
    return sorted(classes, key=lambda c: c.__module__)


def run_all(conn, cfg, tests_pkg, include_groups=None, exclude_groups=None,
            only=None) -> Report:
    include = {g.strip() for g in (include_groups or "").split(",") if g.strip()}
    exclude = {g.strip() for g in (exclude_groups or "").split(",") if g.strip()}
    only = [s.strip() for s in (only or "").split(",") if s.strip()]

    started = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    t0 = datetime.now()
    report = Report(started=started, host=conn.cfg.host, user=conn.cfg.user,
                    model=conn.model(), machine=conn.machine(),
                    strict=cfg.strict,
                    allow_password_ssh=cfg.allow_password_ssh)

    for cls in discover_suites(tests_pkg):
        suite = cls(conn)
        if include and not (include & set(suite.groups)):
            continue
        if exclude & set(suite.groups):
            continue
        if only and not any(suite.name.lower().startswith(o.lower())
                            for o in only):
            continue
        report.suites.append(run_suite(suite))

    report.total_elapsed = (datetime.now() - t0).total_seconds()
    return report