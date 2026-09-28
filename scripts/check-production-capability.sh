#!/usr/bin/env bash
# Reject build targets outside Acadia-Hardware's production matrix v1.
set -euo pipefail

board="${1:?board is required}"
config="${2:?kas board configuration is required}"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

case "${board}" in
    rpi5) machine="raspberrypi5" ;;
    cm5) machine="raspberrypi-cm5-io-board" ;;
    *) fail "BOARD=${board} is unsupported by hardware capability matrix v1.0.0" ;;
esac

[ -f "${config}" ] || fail "board configuration is missing: ${config}"
grep -q "^machine: ${machine}$" "${config}" ||
    fail "${config} must select machine: ${machine}"
grep -q 'ACADIA_HARDWARE_MATRIX_VERSION = "1.0.0"' "${config}" ||
    fail "${config} does not declare hardware capability matrix v1.0.0"
grep -q 'ACADIA_HARDWARE_BOARD_REVISION = "rpi5-cm5-bom-rev-c"' "${config}" ||
    fail "${config} does not declare board revision rpi5-cm5-bom-rev-c"

printf 'production hardware capability: OK (%s, rpi5-cm5-bom-rev-c)\n' "${board}"
