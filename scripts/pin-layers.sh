#!/bin/bash
# scripts/pin-layers.sh — pin every kas/repos/*.yaml to the current HEAD
# of the named branch.
#
# Usage:  scripts/pin-layers.sh [--dry-run]
#
# Iterates the four external layer repos and, for each, resolves the
# tip commit of the configured branch via `git ls-remote` and rewrites
# the `commit: HEAD` line to that 40-char SHA.  Also catches existing
# pinned SHAs and updates them to the new tip.
#
# This is the only sanctioned way to bump a layer SHA.  Never hand-edit
# the kas yaml to a guessed SHA — issue #22, #23, #24: HEAD-tracking
# breaks reproducibility; a guessed SHA breaks reproducibility worse.
#
# After running, do `make build rpi5` end-to-end to validate the new
# pins, then commit kas/repos/*.yaml in a single change.
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_DIR}"

for f in kas/repos/poky.yaml kas/repos/meta-openembedded.yaml \
         kas/repos/meta-raspberrypi.yaml kas/repos/meta-swupdate.yaml; do
    [[ -f "${f}" ]] || continue

    url=$(awk '/^[[:space:]]*url:/{print $2; exit}' "${f}")
    branch=$(awk '/^[[:space:]]*branch:/{print $2; exit}' "${f}")

    if [[ -z "${url}" || -z "${branch}" ]]; then
        echo "  SKIP ${f}: no url/branch"
        continue
    fi

    echo "=== ${f} ==="
    echo "  url    : ${url}"
    echo "  branch : ${branch}"

    # git ls-remote respects the same protocols the kas entry uses
    # (https or git@).  Use the ref's full name to avoid ambiguity.
    sha=$(git ls-remote "${url}" "refs/heads/${branch}" 2>/dev/null \
          | awk '{print $1}' | head -1)
    if [[ -z "${sha}" || "${#sha}" -ne 40 ]]; then
        echo "  ERROR: could not resolve ${url}#${branch} to a 40-char SHA"
        exit 1
    fi
    echo "  tip    : ${sha}"

    if ${DRY_RUN}; then
        echo "  DRY RUN — would rewrite commit: ${sha}"
    else
        sed -i.bak -E "s|^([[:space:]]*commit:[[:space:]]*).*$|\1${sha}|" "${f}"
        rm -f "${f}.bak"
        echo "  pinned."
    fi
done

echo
echo "Done.  Validate with: make build rpi5"
echo "Then commit:           git add kas/repos/*.yaml && git commit"
