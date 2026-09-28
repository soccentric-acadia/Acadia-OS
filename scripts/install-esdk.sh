#!/usr/bin/env bash
# Install the extensible Yocto SDK colocated with this script into /tool.

set -euo pipefail

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ $# -eq 0 ]] || die "usage: $(basename "$0")"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
shopt -s nullglob
installers=("$script_dir"/*-ext-*.sh)
shopt -u nullglob

[[ ${#installers[@]} -eq 1 ]] ||
    die "expected exactly one extensible SDK installer beside this script, found ${#installers[@]}"

echo "Installing $(basename "${installers[0]}") into /tool ..."
sudo "${installers[0]}" -d /tool
echo "eSDK installation complete: /tool"

