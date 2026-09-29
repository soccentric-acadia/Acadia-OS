#!/bin/bash
# flash-sdcard.sh — flash the newest built .wic.bz2/.bmap pair to a block
# device via bmaptool.  Invoked by `make flash` (see Makefile); can also be
# run directly:
#
#   scripts/flash-sdcard.sh DEVICE IMAGE_DIR [--force]
#
# DEVICE      target block device, e.g. /dev/sdb (the whole disk, not a
#             partition such as /dev/sdb1).
# IMAGE_DIR   directory to search for *.wic.bz2 / *.bmap pairs, e.g.
#             build/tmp/deploy/images/bcm2712-rpi5.
# --force     skip the interactive confirmation prompt (FORCE=1 also works).
#
# This is a destructive operation: it overwrites every byte on DEVICE.
# It refuses to run unless:
#   - DEVICE is a block device and a whole disk (not a partition node),
#   - DEVICE is not the host's own root disk,
#   - DEVICE (or any partition on it) is not currently mounted,
#   - a .wic.bz2 has a matching .bmap sitting next to it (a "complete
#     pair"); the newest complete pair by mtime is selected, not the
#     newest by filename sort — a stale image left in IMAGE_DIR by an
#     older build must never be picked over a newer, complete one.

set -euo pipefail

usage() {
    echo "Usage: $0 DEVICE IMAGE_DIR [--force]" >&2
}

FORCE="${FORCE:-0}"
DEVICE=""
IMAGE_DIR=""
for arg in "$@"; do
    case "${arg}" in
        --force) FORCE=1 ;;
        *)
            if [ -z "${DEVICE}" ]; then DEVICE="${arg}";
            elif [ -z "${IMAGE_DIR}" ]; then IMAGE_DIR="${arg}";
            else usage; exit 1;
            fi
            ;;
    esac
done
if [ -z "${DEVICE}" ] || [ -z "${IMAGE_DIR}" ]; then
    usage
    exit 1
fi

# --- DEVICE must be a real, whole-disk block device -------------------------

if [ ! -b "${DEVICE}" ]; then
    echo "ERROR: '${DEVICE}' is not a block device." >&2
    exit 1
fi

DEV_NAME="$(basename "${DEVICE}")"
if [ -e "/sys/class/block/${DEV_NAME}/partition" ]; then
    echo "ERROR: '${DEVICE}' is a partition, not a whole disk." >&2
    echo "       Pass the disk itself (e.g. /dev/sdb, not /dev/sdb1)." >&2
    exit 1
fi

# --- refuse to touch the host's own root disk --------------------------------

ROOT_SRC="$(findmnt -no SOURCE / 2>/dev/null || true)"
if [ -n "${ROOT_SRC}" ]; then
    ROOT_DISK="$(lsblk -no PKNAME "${ROOT_SRC}" 2>/dev/null || true)"
    [ -z "${ROOT_DISK}" ] && ROOT_DISK="$(basename "${ROOT_SRC}")"
    if [ "${DEV_NAME}" = "${ROOT_DISK}" ]; then
        echo "ERROR: '${DEVICE}' looks like the host's own root disk." >&2
        echo "       Refusing to flash it." >&2
        exit 1
    fi
fi

# --- refuse if the device (or any partition on it) is mounted ---------------

MOUNTED="$(lsblk -no MOUNTPOINT "${DEVICE}" 2>/dev/null | grep -v '^$' || true)"
if [ -n "${MOUNTED}" ]; then
    echo "ERROR: '${DEVICE}' has mounted partition(s):" >&2
    echo "${MOUNTED}" | sed 's/^/    /' >&2
    echo "       Unmount them first, then re-run." >&2
    exit 1
fi

# --- find the newest COMPLETE (wic.bz2 + bmap) pair, by mtime ---------------

if [ ! -d "${IMAGE_DIR}" ]; then
    echo "ERROR: image directory '${IMAGE_DIR}' does not exist." >&2
    exit 1
fi

ALL_WIC="$(find "${IMAGE_DIR}" -maxdepth 1 -name '*.wic.bz2' -printf '%T@ %p\n' 2>/dev/null | sort -rn)"
WIC=""
while read -r _ candidate; do
    [ -z "${candidate}" ] && continue
    if [ -f "${candidate%.bz2}.bmap" ]; then
        WIC="${candidate}"
        break
    fi
done <<< "${ALL_WIC}"

if [ -z "${WIC}" ]; then
    echo "ERROR: no .wic.bz2 with a matching .bmap found in '${IMAGE_DIR}'." >&2
    if [ -n "${ALL_WIC}" ]; then
        echo "       .wic.bz2 files seen (none had a matching .bmap next to it):" >&2
        echo "${ALL_WIC}" | awk '{print $2}' | sed 's/^/         /' >&2
    else
        echo "       No .wic.bz2 files found at all — run 'make image' first." >&2
    fi
    exit 1
fi
BMAP="${WIC%.bz2}.bmap"

# --- confirm with the operator before doing anything irreversible -----------

SIZE="$(lsblk -dno SIZE "${DEVICE}" 2>/dev/null || echo unknown)"
MODEL="$(lsblk -dno MODEL "${DEVICE}" 2>/dev/null | sed 's/[[:space:]]*$//')"

echo ""
echo "About to flash:"
echo "  Image : ${WIC}"
echo "  Device: ${DEVICE}  (${MODEL:-unknown model}, ${SIZE})"
echo "THIS WILL ERASE ALL DATA ON ${DEVICE}."
echo ""

if [ "${FORCE}" != "1" ]; then
    printf "Type the device path (%s) to confirm: " "${DEVICE}"
    read -r CONFIRM
    if [ "${CONFIRM}" != "${DEVICE}" ]; then
        echo "Confirmation did not match — aborting." >&2
        exit 1
    fi
fi

echo "Flashing ${WIC} -> ${DEVICE} ..."
bmaptool copy --bmap "${BMAP}" "${WIC}" "${DEVICE}"
sync
echo "Done. Safe to remove ${DEVICE} now."
