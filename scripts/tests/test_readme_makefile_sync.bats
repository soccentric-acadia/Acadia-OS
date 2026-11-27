#!/usr/bin/env bats
# test_readme_makefile_sync.bats — regression test for the
# Makefile / README sync verification fixes for issues #103, #104,
# #105, #106.
#
# These four issues all check that the Makefile's behaviour matches
# what the README claims.  All four are "Met" — the README's claims
# are correct as written, and #105 includes an extra safety check
# (test -b for block device) that the README doesn't explicitly
# document.  This test pins the README's existing wording AND the
# extra block-device check, so a future refactor that drops the
# safety check (or rewrites the README) gets caught at CI time.

setup() {
    SUT_MK="${BATS_TEST_DIRNAME}/../../Makefile"
    SUT_RD="${BATS_TEST_DIRNAME}/../../README.md"
    [ -f "${SUT_MK}" ] || skip "Makefile not found at ${SUT_MK}"
    [ -f "${SUT_RD}" ] || skip "README.md not found at ${SUT_RD}"
}

# --- #103: completion target behaviour matches README §14 -------------

@test "#103: Makefile 'completion' target exists" {
    grep -qE '^completion:' "${SUT_MK}"
}

@test "#103: README §14 documents 'make completion' with 'source ~/.bashrc'" {
    grep -qE 'make completion.*source ~/.bashrc' "${SUT_RD}"
}

@test "#103: completion target appends a 'source' line (matches README claim)" {
    # The README says "appends source line to ~/.bashrc"; verify
    # the target actually appends to ~/.bashrc.
    grep -qE 'completion:.*$\|^[[:space:]]*~/.bashrc' "${SUT_MK}" || \
        grep -qE 'bashrc' "${SUT_MK}"
    # And the actual source line is generated (rpi-make-completion.bash
    # is the file that's sourced).
    grep -qE 'rpi-make-completion\.bash|complete.*make' "${SUT_MK}"
}

# --- #104: clean targets match README §5 -----------------------------

@test "#104: Makefile 'clean' target exists" {
    grep -qE '^clean:' "${SUT_MK}"
}

@test "#104: Makefile 'clean-docker' target exists" {
    grep -qE '^clean-docker:' "${SUT_MK}"
}

@test "#104: Makefile 'clean-all' target exists" {
    grep -qE '^clean-all:' "${SUT_MK}"
}

@test "#104: README §5 lists all three clean targets" {
    # Verify all three appear in the clean-targets table.
    grep -qE '\| `clean`[[:space:]]+\|' "${SUT_RD}"
    grep -qE '\| `clean-docker`[[:space:]]+\|' "${SUT_RD}"
    grep -qE '\| `clean-all`[[:space:]]+\|' "${SUT_RD}"
}

@test "#104: clean-all removes cache downloads and sstate (README claim)" {
    # README says clean-all removes build/ and the cache directories.
    # The Makefile target's body must reference all three (the
    # Makefile uses DL_DIR/SSTATE_DIR variables, whose default
    # values point to cache/downloads/ and cache/sstate-cache/).
    #
    # Use sed to extract the clean-all target body (until the
    # next non-indented line).  Then verify DL_DIR / SSTATE_DIR
    # are referenced.
    sed -n '/^clean-all:/,/^[^[:space:]]/p' "${SUT_MK}" | grep -qE 'DL_DIR'
    sed -n '/^clean-all:/,/^[^[:space:]]/p' "${SUT_MK}" | grep -qE 'SSTATE_DIR'
    grep -qE '^DL_DIR[[:space:]]+\?=[[:space:]]+.*CACHE_DIR\)/downloads' "${SUT_MK}"
    grep -qE '^SSTATE_DIR[[:space:]]+\?=[[:space:]]+.*CACHE_DIR\)/sstate-cache' "${SUT_MK}"
}

# --- #105: flash target validates DEVICE -----------------------------

@test "#105: Makefile 'flash' target exists" {
    grep -qE '^flash:' "${SUT_MK}"
}

@test "#105: flash target validates DEVICE is a block device (issue #105)" {
    # The README doesn't document this extra safety check, but
    # the Makefile has it.  Pin the check so a future refactor
    # doesn't accidentally drop it.
    grep -qE 'test -b.*DEVICE' "${SUT_MK}"
}

@test "#105: flash target errors out if DEVICE is unset" {
    # The Makefile has an ifndef DEVICE guard.
    grep -qE 'ifndef DEVICE' "${SUT_MK}"
    grep -qE 'DEVICE is not set' "${SUT_MK}"
}

@test "#105: README §4 mentions DEVICE=/dev/... example" {
    grep -qE 'make flash.*DEVICE=/dev/' "${SUT_RD}"
}

# --- #106: ensure-* targets match README §11 -------------------------

@test "#106: Makefile 'ensure-image' target exists" {
    grep -qE '^ensure-image:' "${SUT_MK}"
}

@test "#106: Makefile 'ensure-sdk-image' target exists" {
    grep -qE '^ensure-sdk-image:' "${SUT_MK}"
}

@test "#106: Makefile 'ensure-esdk-image' target exists" {
    grep -qE '^ensure-esdk-image:' "${SUT_MK}"
}

@test "#106: README §11 documents all three ensure-* targets" {
    # The targets are listed in the Docker Image Targets table
    # (backtick-wrapped) and in the §11 "Conditional rebuild"
    # section (as `make ensure-*` examples).
    grep -qE '\| `ensure-image`[[:space:]]+\|' "${SUT_RD}"
    grep -qE '\| `ensure-sdk-image`[[:space:]]+\|' "${SUT_RD}"
    grep -qE '\| `ensure-esdk-image`[[:space:]]+\|' "${SUT_RD}"
    grep -qE 'make ensure-sdk-image' "${SUT_RD}"
    grep -qE 'make ensure-esdk-image' "${SUT_RD}"
}

# --- Self-consistency -------------------------------------------------

@test "Makefile: parses without error (make -n help)" {
    run make -n help
    [ "$status" -eq 0 ]
}
