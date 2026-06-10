#!/usr/bin/env bats
# test_partition_race.bats — regression test for issue #28.
#
# Issue #28: rpi5-home-init.sh and expand-rootfs.sh both called
# `parted resizepart N 100%` and raced on first boot.  Whichever
# ran second either failed silently or corrupted the partition
# table.
#
# The fix:
#   - rpi5-home-init.sh is the ONLY first-boot service that resizes
#     a partition.  It grows p4 (/home) to fill the rest of the
#     disk.
#   - p2 (rootfs-a) and p3 (rootfs-b) are STATIC sizes in the WKS —
#     no grow-to-fill on the A/B rootfs slots.
#   - The expand-rootfs recipe was removed (it was never installed
#     into the image anyway — acadia-image.bb doesn't list it in
#     IMAGE_INSTALL, and no recipe RDEPENDS on it).
#
# These tests are the static guard that catches a regression to
# the race:
#   1. rpi5-home-init.sh is the only shipped script calling
#      `parted resizepart`.
#   2. WKS p2/p3 use --fixed-size (not a grow-on-first-boot).
#   3. No recipe in recipes-support/expand-rootfs/ exists (the
#      dead recipe must not be re-added).
#   4. rpi5-home-init.service has no `Before=`/`After=` pointing
#      at a non-existent expand-rootfs.service.

# repo root — the path to the meta-acadia tree.  The test file is
# at meta-acadia/recipes-core/rpi5-home-init/tests/, so to reach
# meta-acadia/ we go up 3 segments.  From there, wic/ and
# recipes-support/ are siblings of recipes-core/.
META_ACADIA="${BATS_TEST_DIRNAME}/../../.."
WKS="${META_ACADIA}/wic/sdimage-rpi5.wks"
DEAD_RECIPE_DIR="${META_ACADIA}/recipes-support/expand-rootfs"

setup() {
    [ -f "${WKS}" ] || skip "WKS not found at ${WKS}"
}

# ── 1. rpi5-home-init.sh is the only resizer ────────────────────────────────

@test "issue #28: only rpi5-home-init.sh calls 'parted resizepart'" {
    # Walk every .sh file in the layer's recipes-core and recipes-support
    # trees.  Any script (other than rpi5-home-init.sh itself) that
    # contains a literal `parted ... resizepart` call is a regression
    # to the race.  This includes the now-deleted expand-rootfs.sh
    # if anyone re-adds it under a different name.
    local offenders
    offenders=$(grep -rlE '\bparted\b.*\bresizepart\b' \
        "${META_ACADIA}/recipes-core" \
        "${META_ACADIA}/recipes-support" \
        2>/dev/null \
        | grep -v 'rpi5-home-init\.sh$' \
        | grep -v 'test_partition_race\.bats$' || true)
    [ -z "${offenders}" ] || {
        echo "Found 'parted resizepart' in unexpected scripts:"
        echo "${offenders}"
        return 1
    }
}

# ── 2. WKS p2/p3 are static (no grow-to-fill) ──────────────────────────────

@test "issue #28: WKS p2 (rootfs-a) is --fixed-size" {
    # The p2 line MUST carry --fixed-size.  A regression to
    # `--size 100%` or removal of --fixed-size would re-introduce
    # the grow-on-first-boot for the A slot.
    grep -qE 'part /[[:space:]]+--source rootfs.*--label rootfs-a.*--fixed-size' "${WKS}"
}

@test "issue #28: WKS p3 (rootfs-b) is --fixed-size" {
    # p3 (the standby slot) is also static — same reason as p2.
    grep -qE 'part[[:space:]]+--source empty.*--label rootfs-b.*--fixed-size' "${WKS}"
}

@test "issue #28: WKS p2/p3 do NOT use --size 100% (grow-to-fill)" {
    # Defensive: the old layout could (theoretically) have used
    # `--size 100%` to mean "use the rest of the disk".  If a
    # future contributor writes that, p2/p3 would push p4 off the
    # card and the /home init service would resize an empty space.
    ! grep -qE 'part.*--size[[:space:]]+100%' "${WKS}"
}

# ── 3. Dead recipe must not be re-added ────────────────────────────────────

@test "issue #28: dead expand-rootfs recipe is not re-introduced" {
    # expand-rootfs.bb is dead code: acadia-image.bb does not list
    # it in IMAGE_INSTALL, and no other recipe RDEPENDS on it.
    # Re-adding it under the same name silently re-introduces a
    # second resizepart path if the contributor also re-adds the
    # service.  Verify the directory is gone.
    [ ! -d "${DEAD_RECIPE_DIR}" ] || {
        echo "Dead expand-rootfs recipe directory exists: ${DEAD_RECIPE_DIR}"
        ls -la "${DEAD_RECIPE_DIR}"
        return 1
    }
}

@test "issue #28: no IMAGE_INSTALL line in the image recipe references expand-rootfs" {
    # Defensive: even if the directory is recreated, it must not
    # be pulled into the image.  Scan acadia-image.bb for any
    # `expand-rootfs` reference.
    local image_recipe="${META_ACADIA}/recipes-core/images/acadia-image.bb"
    [ -f "${image_recipe}" ] || skip "acadia-image.bb not found"
    ! grep -qE 'expand-rootfs' "${image_recipe}"
}

# ── 4. Service ordering is correct ─────────────────────────────────────────

@test "issue #28: rpi5-home-init.service does not depend on a deleted expand-rootfs.service" {
    # The race fix removed expand-rootfs entirely.  Any leftover
    # `Before=expand-rootfs.service` or `After=expand-rootfs.service`
    # in rpi5-home-init.service would be a dangling reference
    # (systemd would warn at boot, not fail).
    local svc="${META_ACADIA}/recipes-core/rpi5-home-init/files/rpi5-home-init.service"
    [ -f "${svc}" ] || skip "rpi5-home-init.service not found"
    ! grep -qE 'expand-rootfs\.service' "${svc}"
}
