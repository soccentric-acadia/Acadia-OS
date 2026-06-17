#!/usr/bin/env bats
# test_image_tags.bats — regression test for per-board Docker
# image tagging in the root Makefile.
#
# Issue #112: KAS_IMAGE, SDK_IMAGE, and ESDK_IMAGE were hardcoded
# to `rpi5-kas:latest`, `rpi5-sdk:latest`, and `rpi5-esdk:latest`
# regardless of BOARD.  Two boards could not co-exist as separate
# Docker images; the second board's build would silently overwrite
# the first.  The fix derives the image name from BOARD so each
# board has its own image.
#
# This test verifies the *Makefile source* and *parsed variables*
# because the image tags are evaluated at build time, not from a
# unit testable function.

setup() {
    SUT="${BATS_TEST_DIRNAME}/../../Makefile"
    [ -f "${SUT}" ] || skip "Makefile not found at ${SUT}"
}

# --- Default values are board-derived, not hardcoded to rpi5 --------------

@test "image tags: KAS_IMAGE defaults to \$(BOARD)-kas:latest" {
    # Issue #112: was hardcoded to rpi5-kas:latest.  Now board-derived.
    grep -qE '^KAS_IMAGE[[:space:]]+\?=[[:space:]]+\$\(BOARD\)-kas:latest' "${SUT}"
}

@test "image tags: SDK_IMAGE defaults to \$(BOARD)-sdk:latest" {
    grep -qE '^SDK_IMAGE[[:space:]]+\?=[[:space:]]+\$\(BOARD\)-sdk:latest' "${SUT}"
}

@test "image tags: ESDK_IMAGE defaults to \$(BOARD)-esdk:latest" {
    grep -qE '^ESDK_IMAGE[[:space:]]+\?=[[:space:]]+\$\(BOARD\)-esdk:latest' "${SUT}"
}

@test "image tags: NO hardcoded rpi5-kas:latest default" {
    ! grep -qE '^KAS_IMAGE[[:space:]]+\?=[[:space:]]+rpi5-kas:latest' "${SUT}"
}

@test "image tags: NO hardcoded rpi5-sdk:latest default" {
    ! grep -qE '^SDK_IMAGE[[:space:]]+\?=[[:space:]]+rpi5-sdk:latest' "${SUT}"
}

@test "image tags: NO hardcoded rpi5-esdk:latest default" {
    ! grep -qE '^ESDK_IMAGE[[:space:]]+\?=[[:space:]]+rpi5-esdk:latest' "${SUT}"
}

# --- Comment documents the per-board rationale ---------------------------

@test "image tags: comment block documents the per-board rationale" {
    grep -qE '[Pp]er-board Docker image tags' "${SUT}"
    grep -qE 'issue #112' "${SUT}"
}

@test "image tags: comment shows CLI override example" {
    grep -qE 'make sdk-image rpi4-64 SDK_IMAGE' "${SUT}"
}

# --- ensure-* targets use the board-derived image tag -------------------

@test "ensure-sdk-image: uses board-derived SDK_IMAGE (issue #112)" {
    # The ensure-sdk-image target inspects $(SDK_IMAGE) — verify
    # that an rpi4-64 invocation looks for rpi4-64-sdk:latest, not
    # rpi5-sdk:latest.
    run make -n ensure-sdk-image BOARD=rpi4-64
    [[ "$output" =~ "rpi4-64-sdk:latest" ]]
    [[ ! "$output" =~ "rpi5-sdk:latest" ]]
}

@test "ensure-esdk-image: uses board-derived ESDK_IMAGE" {
    run make -n ensure-esdk-image BOARD=cm5
    [[ "$output" =~ "cm5-esdk:latest" ]]
    [[ ! "$output" =~ "rpi5-esdk:latest" ]]
}

@test "ensure-image: uses board-derived KAS_IMAGE" {
    run make -n ensure-image BOARD=rpi4-64
    [[ "$output" =~ "rpi4-64-kas:latest" ]]
    [[ ! "$output" =~ "rpi5-kas:latest" ]]
}

@test "sdk-image: shows board-derived SDK_IMAGE in build output" {
    run make -n sdk-image BOARD=cm5
    [[ "$output" =~ "cm5-sdk:latest" ]]
}

@test "esdk-image: shows board-derived ESDK_IMAGE in build output" {
    run make -n esdk-image BOARD=cm5
    [[ "$output" =~ "cm5-esdk:latest" ]]
}

# --- Self-consistency ----------------------------------------------------

@test "Makefile: parses without error (make -n help)" {
    run make -n help
    [ "$status" -eq 0 ]
}

@test "Makefile: parses with BOARD=rpi-armv7 (must not error at parse time)" {
    run make -n -p BOARD=rpi-armv7
    [ "$status" -eq 0 ]
}