#!/usr/bin/env python3
"""Validate YAML syntax for kas configuration files.

Used by `make lint-yaml` (and transitively `make lint` / `make validate`).
Runs inside the KAS build container, which already ships PyYAML as a kas
dependency — this avoids adding a new host dependency (feature.txt §12:
"YAML validation for common, target, and repository configuration
files").

Usage: validate-yaml.py <file> [<file> ...]
"""
import sys

import yaml


def main(paths):
    if not paths:
        print("ERROR: no YAML files given", file=sys.stderr)
        return 1

    failed = []
    for path in paths:
        try:
            with open(path) as f:
                yaml.safe_load(f)
        except Exception as exc:  # noqa: BLE001 - report any parse error
            failed.append((path, exc))

    for path, exc in failed:
        print(f"ERROR: {path}: {exc}", file=sys.stderr)

    if failed:
        print(f"FAILED: {len(failed)}/{len(paths)} YAML file(s) invalid", file=sys.stderr)
        return 1

    print(f"OK: {len(paths)} YAML file(s) valid")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
