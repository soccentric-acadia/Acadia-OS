#!/usr/bin/env bats
# test_acadia_data_init_mount.bats — regression test for issue #46.
#
# Issue #46: acadia-data-init.service creates /home/acadia, then
# var-lib-acadia.mount binds /home/acadia → /var/lib/acadia so
# acadia-client.service finds its persistent state on the /home
# partition (not on the A/B rootfs, which an OTA would wipe).
#
# The defect was that the three units had only soft dependencies:
#   - var-lib-acadia.mount: After=acadia-data-init.service
#   - acadia-client.service: After=var-lib-acadia.mount
#                           Wants=var-lib-acadia.mount
# If the init service failed AFTER the mount was up (e.g. a
# follow-up ExecStart= in init failed), the bind was left in
# place but stale.  If the mount itself never came up
# (WantedBy=multi-user.target for a .mount unit may not be
# preset'd on first boot), the client silently started with
# Wants= satisfied (Wants does not fail the dependent) and
# wrote to the rootfs /var/lib/acadia path.
#
# The fix:
#   - var-lib-acadia.mount: add BindsTo=acadia-data-init.service
#     so the mount is stopped if init dies.
#   - acadia-client.service: add Requires=var-lib-acadia.mount
#     so the daemon cannot start without the mount.
#
# These tests are the static guard that catches a regression to
# the soft-dependency chain.

setup() {
    DATA_INIT_DIR="${BATS_TEST_DIRNAME}/../files"
    CLIENT_DIR="${BATS_TEST_DIRNAME}/../../../recipes-connectivity/acadia-client/files"

    MOUNT_UNIT="${DATA_INIT_DIR}/var-lib-acadia.mount"
    INIT_UNIT="${DATA_INIT_DIR}/acadia-data-init.service"
    CLIENT_UNIT="${CLIENT_DIR}/acadia-client.service"

    [ -f "${MOUNT_UNIT}" ]   || skip "var-lib-acadia.mount not found"
    [ -f "${INIT_UNIT}" ]    || skip "acadia-data-init.service not found"
    [ -f "${CLIENT_UNIT}" ]  || skip "acadia-client.service not found"
}

# ── 1. BindsTo on the mount unit ──────────────────────────────────────────

@test "issue #46: var-lib-acadia.mount has BindsTo=acadia-data-init.service" {
    # The lifetime-tie between mount and init.  After= alone only
    # orders start; BindsTo makes init's failure cascade to the
    # mount (and to the client, via Requires=).
    grep -qE '^BindsTo=acadia-data-init\.service' "${MOUNT_UNIT}"
}

@test "issue #46: var-lib-acadia.mount still has After=acadia-data-init.service" {
    # The BindsTo= is in ADDITION to After= — After= is what orders
    # the *start*; BindsTo= is what orders the lifetime.  Both are
    # needed.  Defensive against a future refactor that drops the
    # After= "because BindsTo is enough" (it isn't — BindsTo doesn't
    # start the unit, it just kills it on failure).
    grep -qE '^After=.*acadia-data-init\.service' "${MOUNT_UNIT}"
}

# ── 2. Requires on the client service ────────────────────────────────────

@test "issue #46: acadia-client.service has Requires=var-lib-acadia.mount" {
    # The hard-fail-on-missing-mount guard.  Wants= is a soft
    # preference; Requires= is what makes the client refuse to
    # start without the bind in place.
    grep -qE '^Requires=var-lib-acadia\.mount' "${CLIENT_UNIT}"
}

@test "issue #46: acadia-client.service still has Wants=var-lib-acadia.mount" {
    # Belt-and-braces: Requires= makes the client fail without
    # the mount; Wants= is the soft preference that systemd
    # pulls in as a transitive dependency.  Keep both — a
    # future contributor who thinks "Requires is enough" is
    # right about lifecycle, wrong about activation order.
    # Wants= is what adds the unit to the transaction.
    grep -qE '^Wants=.*var-lib-acadia\.mount' "${CLIENT_UNIT}"
}

@test "issue #46: acadia-client.service still has After=var-lib-acadia.mount" {
    # After= is what orders the start, even if Requires= would
    # already pull in the mount.  Defensive: drop the After= and
    # the client may start before the mount is up (race).
    grep -qE '^After=.*var-lib-acadia\.mount' "${CLIENT_UNIT}"
}

# ── 3. Init service stays idempotent ─────────────────────────────────────

@test "issue #46: acadia-data-init.service has RemainAfterExit=yes" {
    # RemainAfterExit is what makes a oneshot service count as
    # "active" after ExecStart completes.  Without it, the
    # service is "inactive" after success, BindsTo would kill
    # the mount, and the client would never see the mount
    # as up.
    grep -qE '^RemainAfterExit=yes' "${INIT_UNIT}"
}

@test "issue #46: acadia-data-init.service still After=rpi5-home-init.service" {
    # The init must wait for /home (p4) to be mounted and
    # initialised before creating /home/acadia.  Drop this
    # and the dir is created on the rootfs (volatile).
    grep -qE '^After=.*rpi5-home-init\.service' "${INIT_UNIT}"
}

# ── 4. No silent-failure paths added ─────────────────────────────────────

@test "issue #46: no .path / .timer / .socket unit added (chose hardening only)" {
    # The issue offered three fix levels; we chose "Harden ordering
    # only".  This test guards against a future contributor adding
    # a runtime-repair path unit (acadia-data-init.path) without
    # revisiting the choice.  PathExists= triggers on bind loss
    # are useful but add a moving part — they belong in a
    # follow-up issue, not a drive-by.
    local extra
    extra=$(find "${DATA_INIT_DIR}" -name '*.path' -o -name '*.timer' -o -name '*.socket' 2>/dev/null || true)
    [ -z "${extra}" ] || {
        echo "Unexpected extra unit files in acadia-data-init: ${extra}"
        return 1
    }
}

# ── 5. Recipe wiring ─────────────────────────────────────────────────────

@test "issue #46: SYSTEMD_SERVICE lists both .service and .mount" {
    # The recipe must ship the .mount unit alongside the .service,
    # not just the .service.  Defensive: if a future refactor
    # only lists the .service in SYSTEMD_SERVICE, the .mount is
    # never packaged.
    local recipe="${BATS_TEST_DIRNAME}/../acadia-data-init.bb"
    [ -f "${recipe}" ] || skip "acadia-data-init.bb not found"
    grep -qE 'acadia-data-init\.service' "${recipe}"
    grep -qE 'var-lib-acadia\.mount' "${recipe}"
}
