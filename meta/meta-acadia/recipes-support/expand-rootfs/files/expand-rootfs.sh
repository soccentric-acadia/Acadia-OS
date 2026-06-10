#!/bin/bash
# expand-rootfs.sh — Grow root partition and filesystem to fill the SD card.
# Runs once on first boot via systemd.  A flag file prevents repeated runs.

set -euo pipefail

FLAG="/var/lib/expand-rootfs-done"

if [ -f "$FLAG" ]; then
    echo "expand-rootfs: already done, skipping."
    exit 0
fi

# ── Resolve root block device ───────────────────────────────────────────────
ROOT_DEV=$(findmnt -n -o SOURCE /)
ROOT_DEV_NAME="${ROOT_DEV#/dev/}"

# Issue #42: regex-parsing the device name fails on NVMe
# (nvme0n1p2 — second regex captures (nvme, 0) — wrong disk,
# wrong partition).  Use the same lsblk + /sys/class/block
# pattern as rpi5-home-init.sh: that's portable across mmcblk,
# nvme, sd, vd, and any future block device type.
DISK_NAME=$(lsblk -ndo PKNAME "${ROOT_DEV}" 2>/dev/null || true)
PART_NUM=$(cat "/sys/class/block/${ROOT_DEV_NAME}/partition" 2>/dev/null || true)

if [[ -z "${DISK_NAME}" || -z "${PART_NUM}" ]]; then
    echo "expand-rootfs: cannot determine parent disk for '$ROOT_DEV', aborting." >&2
    exit 1
fi

DISK_DEV="/dev/$DISK_NAME"

echo "expand-rootfs: resizing partition $PART_NUM on $DISK_DEV ..."
parted -s "$DISK_DEV" resizepart "$PART_NUM" 100%

# Inform the kernel of the updated partition table
partprobe "$DISK_DEV" 2>/dev/null || true
udevadm settle

echo "expand-rootfs: growing filesystem on $ROOT_DEV ..."
resize2fs "$ROOT_DEV"

mkdir -p "$(dirname "$FLAG")"
touch "$FLAG"

NEW_SIZE=$(df -h / | awk 'NR==2{print $2}')
echo "expand-rootfs: done — root filesystem is now $NEW_SIZE."
