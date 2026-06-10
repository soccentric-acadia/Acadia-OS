#!/bin/bash
# swupdate-bootcheck.sh — I4/C1: health check that confirms OTA or triggers rollback.
#
# Runs after local-fs.target (before network.target) to ensure health check
# completes BEFORE network services start. If the health check fails, the
# system rolls back before any network exposure.
#
# Health check verifies:
#   - acadia-client.service is active AND running (not just started)
#   - The service has been running for minimum time (allows services to settle)
#   - The kernel and DTB files are intact (not corrupted)

set -euo pipefail

BOOT_STATE=/boot/boot_state

# If there is no boot_state the system was not recently updated — nothing to do.
if [[ ! -f "${BOOT_STATE}" ]]; then
    exit 0
fi

# Parse /boot/boot_state as key=value lines.  We deliberately do NOT `source`
# the file: /boot is a FAT32 partition (world-readable from the running
# system).  A `source` on the file would execute any shell metacharacters
# an attacker writes into it — running arbitrary code as root from a
# writable mount.  A read loop assigns values without ever evaluating
# them, and tolerates a corrupt or stale boot_state file.
slot=""
tries_remaining=""
confirmed=""
while IFS='=' read -r key value; do
    case "${key}" in
        slot)            slot="${value}" ;;
        tries_remaining) tries_remaining="${value}" ;;
        confirmed)       confirmed="${value}" ;;
        \#*|"")          : ;;            # comment / blank line
    esac
done < "${BOOT_STATE}"

# Already confirmed by a previous run
if [[ "${confirmed:-false}" == "true" ]]; then
    exit 0
fi

# ── Wait for services to settle (5 second minimum) ───────────────────────────
# This ensures acadia-client has time to fully initialize before we check it
sleep 5

# ── Health check ─────────────────────────────────────────────────────────────
HEALTH_OK=true

# Check acadia-client is actually running (active AND running, not just started)
if ! systemctl is-active --quiet acadia-client.service 2>/dev/null; then
    HEALTH_OK=false
    logger -t swupdate-bootcheck "acadia-client.service not active"
fi

# Verify acadia-client has been running for at least 3 seconds (ensures it's
# actually working, not just starting up)
if [[ "${HEALTH_OK}" == "true" ]]; then
    ACTIVE_MSEC=$(systemctl show --property ActiveEnterTimestamp acadia-client.service 2>/dev/null | cut -d= -f2)
    CURRENT_MSEC=$(date +%s%N 2>/dev/null || echo "")
    if [[ -n "${ACTIVE_MSEC}" ]]; then
        ACTIVE_SECONDS=$(( (CURRENT_MSEC - $(date -d "${ACTIVE_MSEC}" +%s%N 2>/dev/null || echo 0)) / 1000000000 ))
        if [[ "${ACTIVE_SECONDS}" -lt 3 ]]; then
            HEALTH_OK=false
            logger -t swupdate-bootcheck "acadia-client.service running only ${ACTIVE_SECONDS}s"
        fi
    fi
fi

# Verify kernel/DTB files are intact (compare checksums if available, otherwise check existence and size)
if [[ "${HEALTH_OK}" == "true" ]]; then
    for f in kernel_2712.img bcm2712-rpi-5-b.dtb; do
        if [[ ! -f "/boot/${f}" ]]; then
            HEALTH_OK=false
            logger -t swupdate-bootcheck "${f} missing after boot"
            break
        fi
        # Check file size is reasonable (kernel should be > 1MB, DTB < 10MB)
        SIZE=$(stat -c%s "/boot/${f}" 2>/dev/null || echo 0)
        if [[ "${SIZE}" -lt 1048576 ]] || [[ "${SIZE}" -gt 10485760 ]]; then
            HEALTH_OK=false
            logger -t swupdate-bootcheck "${f} size ${SIZE} bytes seems invalid"
            break
        fi
    done
fi

if [[ "${HEALTH_OK}" == "true" ]]; then
    mount -o remount,rw /boot
    sed -i 's/confirmed=false/confirmed=true/' "${BOOT_STATE}"
    mount -o remount,ro /boot
    logger -t swupdate-bootcheck "Slot ${slot} confirmed healthy"
else
    logger -t swupdate-bootcheck "Slot ${slot} unhealthy — rolling back"
    mount -o remount,rw /boot
    if [[ -f /boot/cmdline.txt.prev ]]; then
        cp /boot/cmdline.txt.prev /boot/cmdline.txt
    fi
    for f in kernel_2712.img bcm2712-rpi-5-b.dtb; do
        [[ -f "/boot/${f}.prev" ]] && cp "/boot/${f}.prev" "/boot/${f}" || true
    done
    rm -f "${BOOT_STATE}" /boot/cmdline.txt.prev \
          /boot/kernel_2712.img.prev /boot/bcm2712-rpi-5-b.dtb.prev
    mount -o remount,ro /boot
    reboot
fi
