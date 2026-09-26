#!/usr/bin/env bash
# generate-manifest.sh — pair a built Acadia image with its promises.
#
# Reads the Yocto rootfs package manifest (the truth of what was built)
# from the deploy dir and writes a JSON manifest the validation suite
# consumes via `--manifest` / `make validate MANIFEST=...`.
#
# Usage:
#   validation/tools/generate-manifest.sh [DEPLOY_DIR]
#   DEPLOY_DIR defaults to the newest deploy/images/<board>_<ts> dir.
#
# Output: validation/manifest.json
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/../manifest.json"
DEPLOY="${1:-}"

if [ -z "$DEPLOY" ]; then
    base="$REPO_ROOT/deploy/images"
    [ -d "$base" ] || { echo "no deploy/images dir; pass DEPLOY_DIR" >&2; exit 1; }
    DEPLOY="$(ls -dt "$base"/*/ 2>/dev/null | head -1)"
fi
echo "manifest source: $DEPLOY"

img_manifest="$(find "$DEPLOY" -maxdepth 2 -name '*acadia-image*.manifest' | head -1)"
[ -n "$img_manifest" ] || { echo "no acadia-image .manifest in $DEPLOY" >&2; exit 1; }

machine="$(basename "$img_manifest" | sed 's/\.manifest$//; s/^acadia-image-//')"
build_id="$(basename "$(dirname "$img_manifest")")"

version_id=""
for f in "$REPO_ROOT"/build/tmp/work/*-linux/os-release/*/image/etc/os-release \
         "$REPO_ROOT"/build/tmp/work/*/acadia-image/*/rootfs/etc/os-release; do
    if [ -e "$f" ]; then
        version_id="$(grep '^VERSION_ID=' "$f" | cut -d= -f2 | tr -d '"')"
        break
    fi
done

export MANIFEST_OUT="$OUT" MANIFEST_MACHINE="$machine" \
       MANIFEST_BUILD_ID="$build_id" MANIFEST_VERSION="${version_id:-}" \
       MANIFEST_FILE="$img_manifest"
python3 - <<'EOF'
import hashlib, json, os
doc = {
    "machine": os.environ["MANIFEST_MACHINE"],
    "build_id": os.environ["MANIFEST_BUILD_ID"],
    "version_id": os.environ["MANIFEST_VERSION"] or None,
    "packages": [l.split()[0] for l in open(os.environ["MANIFEST_FILE"])
                 if l.strip() and not l.strip().startswith("#")],
}
src = os.environ["MANIFEST_FILE"]
doc["manifest_file"] = src
doc["manifest_sha256"] = hashlib.sha256(open(src, "rb").read()).hexdigest()
out = os.environ["MANIFEST_OUT"]
open(out, "w").write(json.dumps(doc, indent=2) + "\n")
print(f"manifest written: {out}")
print(f"  machine={doc['machine']} build={doc['build_id']} "
      f"version={doc['version_id'] or '?'} packages={len(doc['packages'])}")
EOF