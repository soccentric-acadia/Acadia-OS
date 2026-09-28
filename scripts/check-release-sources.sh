#!/usr/bin/env bash
# Verify that the production build configuration consumes the reviewed lock.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="${ROOT}/release-sources.lock"
META="${ROOT}/meta/meta-acadia"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[ -f "${LOCK}" ] || fail "release lock is missing: ${LOCK}"
[ -d "${META}" ] || fail "pinned meta-acadia checkout is missing: ${META}"

# The lock is deliberately a restricted assignment file, not a general shell
# configuration. Reject anything that could make `source` execute code.
if grep -vE '^[[:space:]]*(#[[:print:]]*|$|[A-Z0-9_]+=[A-Za-z0-9.]+)$' "${LOCK}" | grep -q .; then
    fail "release lock has an invalid line"
fi
# shellcheck disable=SC1090
source "${LOCK}"

for key in POKY_SRCREV META_OPENEMBEDDED_SRCREV META_RASPBERRYPI_SRCREV \
           META_SWUPDATE_SRCREV META_LTS_MIXINS_SRCREV META_ACADIA_SRCREV \
           INSTRUMENTATION_SRCREV CONFIGURATION_SRCREV HAL_SRCREV \
           CLIENT_SRCREV TOMLPLUSPLUS_SRCREV RASPBERRYPI_LINUX_SRCREV; do
    value="${!key:-}"
    [[ "${value}" =~ ^[0-9a-f]{40}$ ]] || fail "${key} is not a 40-character SHA"
done
[[ "${KAS_VERSION:-}" =~ ^[0-9]+[.][0-9]+$ ]] || fail "KAS_VERSION is not an exact release"

check_file_contains() {
    local file="$1" needle="$2"
    grep -qF "${needle}" "${file}" || fail "${file#${ROOT}/} does not contain ${needle}"
}

check_file_contains "${ROOT}/docker/yocto/Dockerfile" "ARG KAS_VERSION=${KAS_VERSION}"
check_file_contains "${ROOT}/Makefile" "KAS_VERSION      ?= ${KAS_VERSION}"

check_file_contains "${ROOT}/kas/repos/poky.yaml" "commit: ${POKY_SRCREV}"
check_file_contains "${ROOT}/kas/repos/meta-openembedded.yaml" "commit: ${META_OPENEMBEDDED_SRCREV}"
check_file_contains "${ROOT}/kas/repos/meta-raspberrypi.yaml" "commit: ${META_RASPBERRYPI_SRCREV}"
check_file_contains "${ROOT}/kas/repos/meta-swupdate.yaml" "commit: ${META_SWUPDATE_SRCREV}"
check_file_contains "${ROOT}/kas/repos/meta-lts-mixins.yaml" "commit: ${META_LTS_MIXINS_SRCREV}"
check_file_contains "${ROOT}/kas/repos/meta-acadia.yaml" "commit: ${META_ACADIA_SRCREV}"

check_file_contains "${META}/recipes-instrumentation/instrumentation/instrumentation.bb" \
    "INSTR_SRCREV ?= \"${INSTRUMENTATION_SRCREV}\""
check_file_contains "${META}/recipes-core/webconfig/webconfigd.bb" \
    "SRCREV = \"${CONFIGURATION_SRCREV}\""
check_file_contains "${META}/recipes-bsp/acadia-hal/acadia-hal_git.bb" \
    "SRCREV = \"${HAL_SRCREV}\""
check_file_contains "${META}/recipes-connectivity/acadia-client/acadia-client_git.bb" \
    "SRCREV_client = \"${CLIENT_SRCREV}\""
check_file_contains "${META}/recipes-connectivity/acadia-client/acadia-client_git.bb" \
    "SRCREV_hal = \"${HAL_SRCREV}\""
check_file_contains "${META}/recipes-support/tomlplusplus/tomlplusplus_3.4.0.bb" \
    "SRCREV = \"${TOMLPLUSPLUS_SRCREV}\""
check_file_contains "${META}/recipes-kernel/linux/linux-raspberrypi_6.6.bbappend" \
    "SRCREV_machine:raspberrypi5 = \"${RASPBERRYPI_LINUX_SRCREV}\""

# Guard the two P0-03 regressions that previously made a release image fail:
# malformed RPI_EXTRA_CONFIG assignment and systemd's premature polkit chown.
check_file_contains "${ROOT}/kas/common.yaml" 'RPI_EXTRA_CONFIG ?= " \'
check_file_contains "${ROOT}/kas/common.yaml" 'PACKAGECONFIG:remove:pn-systemd = "polkit"'
check_file_contains "${META}/recipes-core/webconfig/webconfigd.bb" \
    'install -m 0700 -d ${D}${datadir}/polkit-1/rules.d'
check_file_contains "${META}/recipes-instrumentation/instrumentation/instrumentation.bb" \
    'install -m 0700 -d ${D}${datadir}/polkit-1/rules.d'

if grep -R -nE '^[[:space:]]*SRCREV[^#]*=[^#]*\$\{AUTOREV\}' \
    "${META}/recipes-"* --include='*.bb' --include='*.bbappend' 2>/dev/null | grep -q .; then
    fail "AUTOREV is present in a production recipe"
fi

printf 'release source lock: OK\n'
