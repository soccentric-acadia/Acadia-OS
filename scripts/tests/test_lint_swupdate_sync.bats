#!/usr/bin/env bats
# test_lint_swupdate_sync.bats — regression test for the
# `make lint-swupdate-sync` target (and the `make lint` alias).
#
# Issue #116: two byte-identical copies of pre/post-install.sh
# exist (one bundled into .swu, one installed to /usr/lib/swupdate/).
# Per CLAUDE.md C1, drift between them silently regresses the
# rollback chain.  This target asserts the two pairs match.
#
# Test verifies:
#   - The Makefile defines `lint-swupdate-sync` and `lint` targets.
#   - The target exits 0 when the two pairs are byte-identical.
#   - The target exits non-zero when the .swu-side copy drifts.
#   - The error message names both files so the operator can fix
#     the drift without reading the Makefile source.

setup() {
    SUT="${BATS_TEST_DIRNAME}/../../Makefile"
    [ -f "${SUT}" ] || skip "Makefile not found at ${SUT}"

    # Make a backup so the drift-recovery test can restore cleanly.
    BACKUP_DIR=$(mktemp -d)
    cp meta/meta-acadia/swupdate/pre-install.sh      "${BACKUP_DIR}/pre-install.sh"
    cp meta/meta-acadia/swupdate/post-install.sh     "${BACKUP_DIR}/post-install.sh"
    cp meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/pre-install.sh  "${BACKUP_DIR}/pre-install.recipe.sh"
    cp meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/post-install.sh "${BACKUP_DIR}/post-install.recipe.sh"
    export BACKUP_DIR
}

teardown() {
    # Always restore — even if the test fails — so we don't leave
    # the working tree in a drifted state for the next contributor.
    if [ -n "${BACKUP_DIR}" ] && [ -d "${BACKUP_DIR}" ]; then
        cp "${BACKUP_DIR}/pre-install.sh"          meta/meta-acadia/swupdate/pre-install.sh      2>/dev/null || true
        cp "${BACKUP_DIR}/post-install.sh"         meta/meta-acadia/swupdate/post-install.sh     2>/dev/null || true
        cp "${BACKUP_DIR}/pre-install.recipe.sh"   meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/pre-install.sh  2>/dev/null || true
        cp "${BACKUP_DIR}/post-install.recipe.sh"  meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/post-install.sh 2>/dev/null || true
        rm -rf "${BACKUP_DIR}"
    fi
}

# --- Target presence ---------------------------------------------------

@test "Makefile: defines lint-swupdate-sync target" {
    grep -qE '^lint-swupdate-sync:' "${SUT}"
}

@test "Makefile: defines lint target that depends on lint-swupdate-sync" {
    grep -qE '^lint:[[:space:]]+lint-swupdate-sync' "${SUT}"
}

@test "Makefile: lint-swupdate-sync uses diff -q for byte-identical check" {
    # A line-oriented diff would silently allow changes that don't
    # differ in line count but do differ in content.  Use diff -q
    # (quiet — only report if files differ).
    grep -qE 'diff -q' "${SUT}"
}

@test "Makefile: lint-swupdate-sync iterates over pre-install.sh + post-install.sh" {
    grep -qF 'pre-install.sh' "${SUT}"
    grep -qF 'post-install.sh' "${SUT}"
}

@test "Makefile: lint-swupdate-sync error message names both files (issue #116)" {
    # Without naming the two paths in the error, the operator has
    # to read the Makefile to know which copy to fix.
    grep -qE '\.swu-side' "${SUT}"
    grep -qE 'recipe-side' "${SUT}"
}

# --- In-sync behaviour -------------------------------------------------

@test "lint-swupdate-sync: passes when both copies are byte-identical" {
    run make lint-swupdate-sync
    [ "$status" -eq 0 ]
    [[ "$output" =~ "pre-install.sh in sync" ]]
    [[ "$output" =~ "post-install.sh in sync" ]]
}

@test "lint target (alias): passes when both copies are byte-identical" {
    run make lint
    [ "$status" -eq 0 ]
}

# --- Drift detection ---------------------------------------------------

@test "lint-swupdate-sync: detects .swu-side drift on pre-install.sh" {
    echo "# DRIFT INJECTION" >> meta/meta-acadia/swupdate/pre-install.sh
    run make lint-swupdate-sync
    [ "$status" -ne 0 ]
    [[ "$output" =~ "drifted" ]]
    [[ "$output" =~ "pre-install.sh" ]]
}

@test "lint-swupdate-sync: detects recipe-side drift on post-install.sh" {
    echo "# DRIFT INJECTION" >> meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/post-install.sh
    run make lint-swupdate-sync
    [ "$status" -ne 0 ]
    [[ "$output" =~ "drifted" ]]
    [[ "$output" =~ "post-install.sh" ]]
}

@test "lint-swupdate-sync: detects both copies drifting differently" {
    echo "# A" >> meta/meta-acadia/swupdate/post-install.sh
    echo "# B" >> meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/post-install.sh
    run make lint-swupdate-sync
    [ "$status" -ne 0 ]
    [[ "$output" =~ "drifted" ]]
}

# --- Self-consistency --------------------------------------------------

@test "Makefile: parses without error (make -n help)" {
    run make -n help
    [ "$status" -eq 0 ]
}

@test "Makefile: parses with BOARD=rpi-armv7 (must not error at parse time)" {
    run make -n -p BOARD=rpi-armv7
    [ "$status" -eq 0 ]
}
