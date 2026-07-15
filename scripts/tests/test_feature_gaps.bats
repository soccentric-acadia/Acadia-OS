#!/usr/bin/env bats
# test_feature_gaps.bats — regression test for the feature.txt gap-closure
# pass (2026-07-15): make test / make validate / make check-board did not
# exist, and several §3/§6/§8/§11/§12 features documented in feature.txt
# had no corresponding implementation (expand-rootfs never installed,
# no middleware/cloud package groups, no debug/profiling/ptest support,
# no configurable LICENSE_FLAGS_ACCEPTED / kernel boot args / kernel
# fragments, no YAML/Makefile-syntax validation).
#
# This test pins the presence of the new Makefile targets and the new
# feature wiring so a future refactor cannot silently drop them.

setup() {
    ROOT="${BATS_TEST_DIRNAME}/../.."
    SUT="${ROOT}/Makefile"
    [ -f "${SUT}" ] || skip "Makefile not found at ${SUT}"
}

# --- New Makefile targets (feature.txt §12 / §13) --------------------------

@test "Makefile: defines test target (prerequisite checks)" {
    grep -qE '^test:' "${SUT}"
    grep -qF 'command -v docker' "${SUT}"
    grep -qF 'command -v curl' "${SUT}"
}

@test "Makefile: defines validate target (BitBake metadata + feature wiring)" {
    grep -qE '^validate:' "${SUT}"
    grep -qF 'bitbake -p' "${SUT}"
}

@test "Makefile: defines check-board target (per-board MACHINE validation)" {
    grep -qE '^check-board:' "${SUT}"
    grep -qF "grep '^machine:'" "${SUT}"
}

@test "Makefile: defines lint-makefile and lint-yaml, and lint depends on both" {
    grep -qE '^lint-makefile:' "${SUT}"
    grep -qE '^lint-yaml:' "${SUT}"
    grep -qE '^lint:.*lint-makefile' "${SUT}"
    grep -qE '^lint:.*lint-yaml' "${SUT}"
}

@test "check-board: passes against the real kas/boards/*.yaml files" {
    cd "${ROOT}"
    run make check-board
    [ "$status" -eq 0 ]
    [[ "$output" == *"rpi5 -> MACHINE=raspberrypi5"* ]]
}

@test "lint-makefile: passes against the real Makefile" {
    cd "${ROOT}"
    run make lint-makefile
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK: Makefile syntax valid"* ]]
}

@test "test: passes when docker and curl are present" {
    cd "${ROOT}"
    run make test
    [ "$status" -eq 0 ]
}

# --- expand-rootfs wiring (feature.txt §3) ---------------------------------

@test "acadia-image.bb: installs expand-rootfs for single-partition boards" {
    IMG="${ROOT}/meta/meta-acadia/recipes-core/images/acadia-image.bb"
    grep -qF 'IMAGE_INSTALL:append = " expand-rootfs"' "${IMG}"
}

@test "acadia-image.bb: excludes expand-rootfs on the A/B rpi5/cm5 machines" {
    IMG="${ROOT}/meta/meta-acadia/recipes-core/images/acadia-image.bb"
    grep -qF 'IMAGE_INSTALL:remove:raspberrypi5 = "expand-rootfs"' "${IMG}"
    grep -qF 'IMAGE_INSTALL:remove:raspberrypi-cm5-io-board = "expand-rootfs"' "${IMG}"
}

# --- middleware / cloud / debug / ptest wiring (feature.txt §6) -----------

@test "packagegroup-acadia-middleware recipe exists and is installed" {
    RECIPE="${ROOT}/meta/meta-acadia/recipes-core/packagegroup-acadia-middleware/packagegroup-acadia-middleware.bb"
    [ -f "${RECIPE}" ]
    grep -qF 'inherit packagegroup' "${RECIPE}"
    IMG="${ROOT}/meta/meta-acadia/recipes-core/images/acadia-image.bb"
    grep -qF 'packagegroup-acadia-middleware' "${IMG}"
}

@test "packagegroup-acadia-cloud recipe exists (documented, opt-in)" {
    RECIPE="${ROOT}/meta/meta-acadia/recipes-core/packagegroup-acadia-cloud/packagegroup-acadia-cloud.bb"
    [ -f "${RECIPE}" ]
    grep -qF 'inherit packagegroup' "${RECIPE}"
    IMG="${ROOT}/meta/meta-acadia/recipes-core/images/acadia-image.bb"
    grep -qF 'packagegroup-acadia-cloud' "${IMG}"
}

@test "acadia-image.bb: enables tools-debug and ptest-pkgs IMAGE_FEATURES" {
    IMG="${ROOT}/meta/meta-acadia/recipes-core/images/acadia-image.bb"
    grep -qF 'IMAGE_FEATURES += "tools-debug"' "${IMG}"
    grep -qF 'IMAGE_FEATURES += "ptest-pkgs"' "${IMG}"
    grep -qF 'gdbserver perf trace-cmd valgrind' "${IMG}"
}

# --- kas/common.yaml configurables (feature.txt §3, §8, §11, §12) ---------

@test "kas/common.yaml: LICENSE_FLAGS_ACCEPTED is configurable" {
    grep -qF 'LICENSE_FLAGS_ACCEPTED' "${ROOT}/kas/common.yaml"
}

@test "kas/common.yaml: ptest DISTRO_FEATURES enabled" {
    grep -qE 'DISTRO_FEATURES:append = " ptest"' "${ROOT}/kas/common.yaml"
}

@test "kas/common.yaml: SDKIMAGE_FEATURES includes dev-pkgs and dbg-pkgs" {
    grep -qF 'SDKIMAGE_FEATURES:append' "${ROOT}/kas/common.yaml"
    grep -qF 'dev-pkgs dbg-pkgs' "${ROOT}/kas/common.yaml"
}

@test "kas/common.yaml: configurable kernel boot arguments (CMDLINE)" {
    grep -qF 'ACADIA_EXTRA_CMDLINE' "${ROOT}/kas/common.yaml"
    grep -qE 'CMDLINE:append = " \$\{ACADIA_EXTRA_CMDLINE\}"' "${ROOT}/kas/common.yaml"
}

@test "scripts/validate-yaml.py exists and is used by lint-yaml" {
    [ -f "${ROOT}/scripts/validate-yaml.py" ]
    grep -qF 'scripts/validate-yaml.py' "${SUT}"
}

# --- kernel fragments (feature.txt §3) --------------------------------------

@test "linux-raspberrypi bbappend: supports configurable kernel fragments" {
    BBAPPEND="${ROOT}/meta/meta-acadia/recipes-kernel/linux/linux-raspberrypi_6.6.bbappend"
    grep -qF 'file://fragments/acadia-base.cfg' "${BBAPPEND}"
    [ -f "${ROOT}/meta/meta-acadia/recipes-kernel/linux/files/fragments/acadia-base.cfg" ]
}
