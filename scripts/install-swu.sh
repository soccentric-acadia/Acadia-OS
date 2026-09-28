#!/usr/bin/env bash
# Copy the signed SWUpdate bundle colocated with this script to a target and install it.

set -euo pipefail

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ $# -eq 1 ]] || die "usage: $(basename "$0") [user@]raspberry-pi-host"

target="$1"
case "$target" in
    -*|*$'\n'*|*$'\r'*) die "invalid SSH destination" ;;
esac

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
shopt -s nullglob
bundles=("$script_dir"/*.swu)
shopt -u nullglob

[[ ${#bundles[@]} -eq 1 ]] ||
    die "expected exactly one .swu bundle beside this script, found ${#bundles[@]}"

bundle="${bundles[0]}"
remote_bundle="/tmp/$(basename "$bundle")"

echo "Copying $(basename "$bundle") to $target:$remote_bundle ..."
scp -o StrictHostKeyChecking=yes -- "$bundle" "$target:$remote_bundle"
echo "Installing the copied bundle with SWUpdate on $target ..."
ssh -o StrictHostKeyChecking=yes -- "$target" \
    "sudo swupdate -i $(printf '%q' "$remote_bundle")"
echo "SWUpdate completed successfully on $target."
