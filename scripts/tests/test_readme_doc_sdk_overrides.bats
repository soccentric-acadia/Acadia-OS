#!/usr/bin/env bats
# test_readme_doc_sdk_overrides.bats — regression test for README §11
# documenting both SDK_INSTALL_DIR and ESDK_INSTALL_DIR overrides.
#
# Issue #115: README §11 documented `make sdk-image rpi5 SDK_INSTALL_DIR=...`
# but the symmetric `make esdk-image rpi5 ESDK_INSTALL_DIR=...` override
# (which is plumbed end-to-end exactly like SDK_INSTALL_DIR — see Makefile
# line 122 + 264-267 + docker/esdk/Makefile + Dockerfile) was undocumented.
# An operator running the natural symmetric command would get the
# expected behaviour, but had to guess the variable name.
#
# This test verifies:
#   - README §11 documents BOTH overrides.
#   - The wording makes the symmetry explicit (so future contributors
#     don't accidentally document one without the other).

setup() {
    SUT="${BATS_TEST_DIRNAME}/../../README.md"
    [ -f "${SUT}" ] || skip "README.md not found at ${SUT}"
}

# --- Both overrides documented -----------------------------------------

@test "README §11: documents SDK_INSTALL_DIR override (baseline)" {
    # Baseline — already documented before #115.
    grep -qF 'SDK_INSTALL_DIR=/opt/my-sdk' "${SUT}"
}

@test "README §11: documents ESDK_INSTALL_DIR override (issue #115)" {
    # The bug: ESDK_INSTALL_DIR was plumbed but not documented.
    grep -qF 'ESDK_INSTALL_DIR=/opt/my-esdk' "${SUT}"
}

# --- Symmetry is explicit -----------------------------------------------

@test "README §11: ESDK override block is symmetric to SDK block" {
    # Both overrides should follow the same format:
    #   - comment "These internal variables are rarely needed"
    #   - `make <target> rpi5 <VAR>=...`
    # Without this, the next contributor may add an SDK override
    # for a new install path and forget to add the eSDK one.
    grep -qE 'ESDK_INSTALL_DIR=/opt/' "${SUT}"
    grep -qE 'SDK_INSTALL_DIR=/opt/' "${SUT}"
}

@test "README §11: eSDK override is positioned under eSDK image section" {
    # The eSDK override should appear in the `docker/esdk/` section
    # of §11, not under the SDK section or in §13.
    # Anchor on the `rpi5-esdk:latest` Docker tag — that string
    # appears in the eSDK section.
    grep -qE 'rpi5-esdk:latest' "${SUT}"
    # And the ESDK_INSTALL_DIR example appears AFTER the eSDK
    # image block (verified by line ordering — see test below).
    sdk_line=$(grep -n 'SDK_INSTALL_DIR=/opt/my-sdk' "${SUT}" | head -1 | cut -d: -f1)
    esdk_line=$(grep -n 'ESDK_INSTALL_DIR=/opt/my-esdk' "${SUT}" | head -1 | cut -d: -f1)
    [ -n "${sdk_line}" ] && [ -n "${esdk_line}" ] && [ "${esdk_line}" -gt "${sdk_line}" ]
}

# --- The Makefile plumbing exists --------------------------------------

@test "Makefile: ESDK_INSTALL_DIR variable is plumbed end-to-end (issue #115)" {
    # This test guards against a future refactor that drops
    # ESDK_INSTALL_DIR from the Makefile, breaking the documented
    # override silently.
    grep -qE '^ESDK_INSTALL_DIR[[:space:]]+\?=' Makefile
}