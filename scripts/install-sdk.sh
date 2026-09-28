#!/usr/bin/env bash
# Install the standard Yocto SDK colocated with this script into /tool.

set -euo pipefail

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ $# -eq 0 ]] || die "usage: $(basename "$0")"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
shopt -s nullglob
installers=("$script_dir"/*.sh)
shopt -u nullglob

filtered=()
for installer in "${installers[@]}"; do
    name="$(basename "$installer")"
    [[ "$name" != "$(basename "$0")" && "$name" != *-ext-* ]] &&
        filtered+=("$installer")
done

[[ ${#filtered[@]} -eq 1 ]] ||
    die "expected exactly one standard SDK installer beside this script, found ${#filtered[@]}"

echo "Installing $(basename "${filtered[0]}") into /tool ..."
sudo "${filtered[0]}" -d /tool
echo "SDK installation complete: /tool"

