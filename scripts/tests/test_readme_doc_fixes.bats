#!/usr/bin/env bats
# test_readme_doc_fixes.bats — regression test for the README
# documentation fixes in issues #94, #95, #96, #97, #98, #99,
# #100, #101.
#
# These fixes update the README to match the actual state of the
# repo:
#   - #94: core-image-full-cmdline.bbappend → acadia-image.bb
#   - #95: rpi user has no password (account locked)
#   - #96: kas/base.yaml → kas/common.yaml
#   - #97: same as #96 (troubleshooting section)
#   - #98: cm4 added to board list
#   - #99: full path is meta/meta-acadia/...
#   - #100: SWU_KERNEL/SWU_DTB documented per-board
#   - #101: protobuf-compiler deliberately excluded
#
# Each test pins the new wording so a future contributor editing
# the README can't silently revert the fix.

setup() {
    SUT="${BATS_TEST_DIRNAME}/../../README.md"
    [ -f "${SUT}" ] || skip "README.md not found at ${SUT}"
}

# --- #94: image recipe name -------------------------------------------

@test "README §13: 'Adding packages' references acadia-image.bb (issue #94)" {
    grep -qF 'meta/meta-acadia/recipes-core/images/acadia-image.bb' "${SUT}"
    # And the old bbappend name is gone
    ! grep -qF 'core-image-full-cmdline.bbappend' "${SUT}"
}

@test "README §7: image is 'acadia-image' (inherits core-image-full-cmdline)" {
    grep -qF 'image is `acadia-image`' "${SUT}"
}

# --- #95: rpi user has no password ------------------------------------

@test "README §7: rpi user account is locked, no password (issue #95)" {
    # The old README said "Password: rpi" but the recipe locks the
    # account with usermod -L (acadia-image.bb:62).  The new
    # wording must mention the lock and explain SSH-key access.
    grep -qE 'account is locked' "${SUT}"
    grep -qE 'SSH-key access only' "${SUT}"
    # The old "Password: rpi" must be gone
    ! grep -qE 'Password:[[:space:]]*\*\*`rpi`\*\*' "${SUT}"
}

# --- #96, #97: kas/common.yaml (not kas/base.yaml) ---------------------

@test "README: no references to kas/base.yaml (issues #96, #97)" {
    # All 7 kas/base.yaml references should be replaced with
    # kas/common.yaml.
    ! grep -qF 'kas/base.yaml' "${SUT}"
}

@test "README: kas/common.yaml is the shared baseline (issue #96)" {
    grep -qF '`kas/common.yaml` — shared baseline' "${SUT}"
}

@test "README §15: CONF_VERSION reference is kas/common.yaml (issue #97)" {
    # The troubleshooting section must reference the right file.
    grep -qE 'CONF_VERSION.*`kas/common.yaml`' "${SUT}"
}

# --- #98: cm4 in board list -------------------------------------------

@test "README §3: cm4 is in the board list (issue #98)" {
    # The old list said "cm1 / cm3 / cm5"; the fix adds cm4.
    grep -qE 'cm1.*cm3.*cm4.*cm5' "${SUT}"
}

# --- #99: full path is meta/meta-acadia/... ---------------------------

@test "README §13: Wi-Fi config path is full meta/meta-acadia/... (issue #99)" {
    grep -qF 'meta/meta-acadia/recipes-connectivity/rpi5-connectivity/files/wpa_supplicant-wlan0.conf' "${SUT}"
}

# --- #100: SWU_KERNEL/SWU_DTB documented ------------------------------

@test "README §9: documents SWU_KERNEL/SWU_DTB per-board (issue #100)" {
    grep -qF 'SWU_KERNEL' "${SUT}"
    grep -qF 'SWU_DTB' "${SUT}"
    # And at least one per-board example (rpi5 or rpi4-64)
    grep -qE 'kernel_2712\.img.*bcm2712-rpi-5-b\.dtb' "${SUT}"
    grep -qE 'kernel_2711\.img.*bcm2711-rpi-4-b\.dtb' "${SUT}"
}

# --- #101: protobuf-compiler deliberately excluded --------------------

@test "README §7: protobuf-compiler is excluded from the package list (issue #101)" {
    # The old list said "protobuf, protobuf-compiler, protobuf-lite".
    # The fix omits protobuf-compiler from the list.  Look at the
    # line that lists the protobuf packages (line 305 in the new
    # README) — it should NOT contain 'protobuf-compiler' as a
    # package name.  Anchored on the leading '- `protobuf`,' marker.
    line=$(grep -E '^- .protobuf.,' "${SUT}" | head -1)
    # The exact line that starts with '- `protobuf`,' should not
    # list 'protobuf-compiler' as a comma-separated package.
    if echo "${line}" | grep -qF 'protobuf-compiler,'; then
        echo "ERROR: package list still includes 'protobuf-compiler,'"
        return 1
    fi
    # And the broader protobuf-lite package is still listed.
    grep -qE 'protobuf-lite' "${SUT}"
}

# --- #93: synaptics-killswitch note in kas/common.yaml ---------------

@test "kas/common.yaml: no LICENSE_FLAGS_ACCEPTED for synaptics (issue #93)" {
    # The kas config is read by the swu/sw-description test below;
    # this one verifies the kas config change.
    ! grep -qF 'synaptics-killswitch' kas/common.yaml
    # And the explanatory comment is present
    grep -qF 'do not add' kas/common.yaml
}

# --- #102: extrausers uses -M (--no-create-home) ---------------------

@test "acadia-image.bb: extrausers uses -M, not -m (issue #102)" {
    # The old line was 'useradd -m -s /bin/bash -G sudo rpi'.
    # The new line drops -m (and adds -M) to skip the rootfs home
    # creation, which is wasted because p4 (/home) is recreated
    # by rpi5-home-init on first boot.
    grep -qE '^[[:space:]]*useradd -M -s /bin/bash -G sudo rpi' meta/meta-acadia/recipes-core/images/acadia-image.bb
}

# --- Self-consistency -------------------------------------------------

@test "README: no stale references (excluding comment markers)" {
    # Final sweep — flag any obvious stale references that a
    # reader would hit before #94-#101 were filed.  Comments
    # referencing the old wording (e.g. "issue #X: was Y") are
    # fine; only package lists and direct instructions count.
    # Strip lines that are inside markdown comments or are
    # prefixed with the "issue #NN:" marker.
    noncomment=$(grep -vE '^[[:space:]]*<!--|issue #[0-9]+:' "${SUT}" || true)
    for forbidden in \
        'core-image-full-cmdline.bbappend' \
        'kas/base.yaml' \
        'protobuf-compiler'; do
        if echo "${noncomment}" | grep -qF "${forbidden}"; then
            echo "ERROR: README still references '${forbidden}' (non-comment)"
            return 1
        fi
    done
}
