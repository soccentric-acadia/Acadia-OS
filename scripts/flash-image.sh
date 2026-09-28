#!/usr/bin/env bash
# Write the WIC image colocated with this script to an explicitly selected SD card.

set -euo pipefail

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ $# -eq 1 ]] || die "usage: $(basename "$0") /dev/sdX"

device="$1"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

[[ -b "$device" ]] || die "$device is not a block device"
[[ "$(lsblk -dn -o TYPE "$device")" == "disk" ]] ||
    die "$device is not a whole-disk device; specify its parent disk"

root_source="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
root_parent="$(lsblk -no PKNAME "$root_source" 2>/dev/null || true)"
if [[ -n "$root_parent" && "$device" == "/dev/$root_parent" ]]; then
    die "refusing to overwrite the host root disk: $device"
fi

shopt -s nullglob
images=("$script_dir"/*.wic.bz2)
shopt -u nullglob
[[ ${#images[@]} -eq 1 ]] ||
    die "expected exactly one .wic.bz2 image beside this script, found ${#images[@]}"

image="${images[0]}"
bmap="${image%.bz2}.bmap"
[[ -f "$bmap" ]] || die "missing matching bmap file: $(basename "$bmap")"

echo "The WIC image owns the complete partition layout, including the FAT32 boot partition."
echo "It will permanently erase every partition on $device:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS "$device"
read -r -p "Type the exact device path ($device) to continue: " confirmation
[[ "$confirmation" == "$device" ]] || die "confirmation did not match; no data was written"

while IFS= read -r child; do
    mountpoint="$(findmnt -nr -S "$child" -o TARGET 2>/dev/null || true)"
    if [[ -n "$mountpoint" ]]; then
        [[ "$mountpoint" != "/" ]] ||
            die "refusing to unmount the host root filesystem on $child"
        echo "Unmounting $child from $mountpoint ..."
        sudo umount "$child"
    fi
done < <(lsblk -lnpo NAME "$device")

echo "Writing $(basename "$image") to $device ..."
sudo bmaptool copy --bmap "$bmap" "$image" "$device"
sync
echo "Complete. Safely eject $device before removing the SD card."

