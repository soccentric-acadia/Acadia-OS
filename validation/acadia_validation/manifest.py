"""Build manifest: load and pair a built image with the running target.

The manifest is generated host-side from the build tree by
`validation/tools/generate-manifest.sh` (packages come from the Yocto rootfs
manifest, the actual truth of what was built). The suite diffs *actual vs
declared* instead of a frozen copy of the recipe.
"""

from __future__ import annotations

import json
from pathlib import Path


def load_manifest(path: str) -> dict | None:
    p = Path(path)
    if not p.exists():
        return None
    return json.loads(p.read_text())


def pairing_problems(manifest: dict | None, os_release: dict,
                     machine: str, model: str) -> list[str]:
    """Compare the booted target against the declared build.

    Returns a list of problems (empty = paired).
    """
    if not manifest:
        return []
    problems = []
    want = manifest.get("machine", "")
    if want and machine not in ("unknown",):
        # both sides derive from different sources; compare family prefixes
        if want.split("-")[0] not in machine \
                and machine.split("-")[0] not in want:
            problems.append(f"machine mismatch: target={machine} "
                            f"manifest={want}")
    version = manifest.get("version_id")
    if version and os_release.get("VERSION_ID") and \
            str(version) != os_release.get("VERSION_ID"):
        problems.append(f"os-release VERSION_ID={os_release.get('VERSION_ID')!r} "
                        f"manifest={version!r}")
    return problems