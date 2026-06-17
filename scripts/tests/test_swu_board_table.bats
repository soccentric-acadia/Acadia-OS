#!/usr/bin/env bats
# test_swu_board_table.bats — regression test for the per-board
# SWU_KERNEL / SWU_DTB table in the root Makefile.
#
# Issue #111: the table was missing entries for rpi-armv7, rpi-armv8,
# cm1, and cm3 — all four boards were listed as supported in the
# Makefile header and in README §3, but `make swu <board>` would
# build a .swu with empty kernel/DTB filenames, producing a
# cpio entry that SWUpdate would reject on install.  The fix:
# add cm1/cm3 entries, and fail closed at the top of the `swu`
# target for boards genuinely not in the table.
#
# This test verifies the *Makefile source* because the table is
# evaluated at build time, not from a unit testable function.

setup() {
    SUT="${BATS_TEST_DIRNAME}/../../Makefile"
    [ -f "${SUT}" ] || skip "Makefile not found at ${SUT}"
}

# --- Table presence --------------------------------------------------------

@test "swu table: has entry for rpi5" {
    grep -qE 'ifeq.*BOARD.*rpi5' "${SUT}"
    grep -qE 'SWU_KERNEL.*=.*kernel_2712\.img' "${SUT}"
    grep -qE 'SWU_DTB.*=.*bcm2712-rpi-5-b\.dtb' "${SUT}"
}

@test "swu table: has entry for cm5" {
    grep -qE 'ifeq.*BOARD.*cm5' "${SUT}"
}

@test "swu table: has entry for cm4" {
    grep -qE 'ifeq.*BOARD.*cm4' "${SUT}"
    grep -qE 'SWU_KERNEL.*=.*kernel_2711\.img' "${SUT}"
    grep -qE 'SWU_DTB.*=.*bcm2711-rpi-cm4-io\.dtb' "${SUT}"
}

@test "swu table: has entry for cm3 (issue #111)" {
    grep -qE 'ifeq.*BOARD.*cm3' "${SUT}"
    grep -qE 'SWU_KERNEL.*=.*kernel\.img' "${SUT}"
    grep -qE 'SWU_DTB.*=.*bcm2837-rpi-cm3\.dtb' "${SUT}"
}

@test "swu table: has entry for cm1 (issue #111)" {
    grep -qE 'ifeq.*BOARD.*cm1' "${SUT}"
    grep -qE 'SWU_DTB.*=.*bcm2835-rpi-cm\.dtb' "${SUT}"
}

@test "swu table: has entry for rpi4-64 / rpi4 family" {
    grep -qE 'filter rpi4%' "${SUT}"
    grep -qE 'SWU_KERNEL.*=.*kernel_2711\.img' "${SUT}"
    grep -qE 'SWU_DTB.*=.*bcm2711-rpi-4-b\.dtb' "${SUT}"
}

@test "swu table: has entry for rpi3-64 / rpi3 family" {
    grep -qE 'filter rpi3%' "${SUT}"
    grep -qE 'SWU_KERNEL.*=.*kernel_2710\.img' "${SUT}"
    grep -qE 'SWU_DTB.*=.*bcm2710-rpi-3-b\.dtb' "${SUT}"
}

@test "swu table: has entry for rpi2" {
    grep -qE 'ifeq.*BOARD.*rpi2' "${SUT}"
    grep -qE 'SWU_KERNEL.*=.*kernel7\.img' "${SUT}"
}

@test "swu table: has entry for rpi1" {
    grep -qE 'ifeq.*BOARD.*rpi1' "${SUT}"
    grep -qE 'SWU_DTB.*=.*bcm2708-rpi-b\.dtb' "${SUT}"
}

@test "swu table: has entry for rpi0 family" {
    grep -qE 'filter rpi0%' "${SUT}"
    grep -qE 'SWU_DTB.*=.*bcm2708-rpi-zero\.dtb' "${SUT}"
}

# --- Fail-closed guard ----------------------------------------------------

@test "swu target: fail-closed guard checks SWU_KERNEL (issue #111)" {
    # The new guard at the top of the `swu:` recipe must abort
    # with exit 1 if SWU_KERNEL is empty.
    grep -qE '@test -n' "${SUT}"
    grep -qE 'SWU_KERNEL is undefined' "${SUT}"
}

@test "swu target: fail-closed guard checks SWU_DTB" {
    grep -qE 'SWU_DTB is undefined' "${SUT}"
}

@test "swu target: fail-closed error message references Makefile table" {
    grep -qE 'per-board table' "${SUT}"
}

@test "swu target: fail-closed error message shows CLI override example" {
    grep -qE 'SWU_KERNEL=kernel' "${SUT}"
    grep -qE 'SWU_DTB=bcm' "${SUT}"
}

# --- Make self-consistency (no parse error) ------------------------------

@test "Makefile: parses without error (make -n help)" {
    run make -n help
    [ "$status" -eq 0 ]
}

@test "Makefile: parses with BOARD=rpi-armv7 (must not error at parse time)" {
    # The table itself is evaluated lazily; the fail-closed guard
    # runs at recipe execution, not at parse.  A parse-only check
    # must succeed even for boards not in the table.
    run make -n -p BOARD=rpi-armv7
    [ "$status" -eq 0 ]
}
