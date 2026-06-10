#!/usr/bin/env bats
# test_swu_signing_gate.bats — regression test for the `make swu`
# fail-closed signing gate.
#
# Issue #21: the previous implementation warned about a missing
# private key but packed the .swu anyway.  On a production target
# with `public-key = /etc/swupdate/swupdate-public.pem` in
# swupdate.cfg, the unsigned .swu is rejected on install — and the
# operator's `make swu` returned success, masking the failure.
#
# The fix is fail-closed: the Makefile aborts with exit 1 if
# swupdate-private.pem is missing, unless SWU_ALLOW_UNSIGNED=1 is
# set explicitly (in which case the resulting .swu is still
# rejected on target, but the build pipeline can iterate).
#
# This test inlines the gate logic and exercises all three paths:
# missing key (fail), present key (pass), present key + override
# (still passes, override is irrelevant when the key is present).

setup() {
    TMP=$(mktemp -d)
    KEY="${TMP}/swupdate-private.pem"
    PUB="${TMP}/swupdate-public.pem"
    # Generate a throwaway 2048-bit keypair; the gate does not
    # check key size, only file presence.
    openssl genrsa -out "${KEY}" 2048 >/dev/null 2>&1
    openssl rsa -in "${KEY}" -pubout -out "${PUB}" >/dev/null 2>&1
}

teardown() {
    rm -rf "${TMP}"
}

# Inline copy of the gate logic from the Makefile's `swu` target.
# Returns 0 if the build would proceed; non-zero if it would abort.
check_swu_gate() {
    local key_path="$1"
    if [ ! -f "${key_path}" ]; then
        # In the Makefile, the abort path is: print error, then
        # `test "${SWU_ALLOW_UNSIGNED}" = "1" || exit 1`.
        test "${SWU_ALLOW_UNSIGNED:-}" = "1"
        return $?
    fi
    # Key is present — always proceeds.
    return 0
}

# Run check_swu_gate with an explicit SWU_ALLOW_UNSIGNED value.
# Usage:  gate_with <env-value> <key-path>
#   env-value: the literal value to set SWU_ALLOW_UNSIGNED to
#   key-path:  the path to swupdate-private.pem to test
# The function exports the env var to a subshell where
# check_swu_gate is callable.
gate_with() {
    local env_val="$1"
    local key_path="$2"
    ( SWU_ALLOW_UNSIGNED="${env_val}" check_swu_gate "${key_path}" )
}

@test "swu gate: missing key aborts (default)" {
    ! check_swu_gate "/nonexistent/path/swupdate-private.pem"
}

@test "swu gate: missing key + SWU_ALLOW_UNSIGNED=1 proceeds" {
    gate_with "1" "/nonexistent/path/swupdate-private.pem"
}

@test "swu gate: present key proceeds (no override needed)" {
    check_swu_gate "${KEY}"
}

@test "swu gate: present key + SWU_ALLOW_UNSIGNED=1 still proceeds" {
    gate_with "1" "${KEY}"
}

@test "swu gate: empty SWU_ALLOW_UNSIGNED is treated as unset" {
    ! gate_with "" "/nonexistent/path/swupdate-private.pem"
}

@test "swu gate: SWU_ALLOW_UNSIGNED=0 is treated as unset" {
    # The Makefile uses `test "${SWU_ALLOW_UNSIGNED}" = "1"`, which
    # compares against the literal string "1" — only an exact "1"
    # passes, anything else (0, true, yes, empty) aborts.
    ! gate_with "0" "/nonexistent/path/swupdate-private.pem"
}
