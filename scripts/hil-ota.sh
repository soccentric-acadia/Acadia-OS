#!/usr/bin/env bash
# hil-ota.sh — hardware-in-the-loop OTA test for one Acadia board (OS-065).
#
# Drives a real device over its WebConfig API through the three things the
# A/B contract promises:
#
#   1. update   — upload + install a signed .swu to the inactive slot,
#                 reboot-to-apply, come back on the new slot;
#   2. confirm  — the new slot ends up confirmed (health-gated bootcheck, or
#                 an explicit /updates/confirm when HIL_MANUAL_CONFIRM=1);
#   3. rollback — install again, reboot-to-apply, and cut power while the
#                 firmware's one-shot tryboot is still in progress (before
#                 userspace can confirm). The next boot must come back on the
#                 previous, confirmed slot.
#
# Required environment:
#   HIL_DEVICE          device address (WebConfig on https://$HIL_DEVICE)
#   HIL_USER/HIL_PASS   a WebConfig admin account on the device
#   HIL_SWU             signed bundle to install
#   HIL_POWER_CYCLE     command that power-cycles the board (e.g. a relay or
#                       `uhubctl -l 1-1 -p 2 -a cycle`); step 3 only
# Optional:
#   HIL_TIMEOUT (default 600 s per boot), HIL_INSECURE=1 (self-signed TLS),
#   HIL_SCHEME (default https; http only for a local dev daemon),
#   HIL_MANUAL_CONFIRM=1, HIL_SKIP_ROLLBACK=1.
#
# Exit 0 only when every step held. Each failure names the step.

set -euo pipefail

: "${HIL_DEVICE:?}" "${HIL_USER:?}" "${HIL_PASS:?}" "${HIL_SWU:?}"
TIMEOUT="${HIL_TIMEOUT:-600}"
BASE="${HIL_SCHEME:-https}://${HIL_DEVICE}/api/v1"
JAR="$(mktemp)"; trap 'rm -f "$JAR"' EXIT
CURL=(curl -sS --fail-with-body -b "$JAR" -c "$JAR" --max-time 900)
[[ "${HIL_INSECURE:-0}" == 1 ]] && CURL+=(-k)
CSRF=""

step() { echo "== [hil-ota] $*"; }
die()  { echo "FAIL [hil-ota] $*" >&2; exit 1; }

login() {
    "${CURL[@]}" -H 'Content-Type: application/json' \
        -d "$(jq -nc --arg u "$HIL_USER" --arg p "$HIL_PASS" '{username:$u,password:$p}')" \
        "$BASE/auth/login" >/dev/null
    CSRF="$("${CURL[@]}" "$BASE/auth/whoami" | jq -r '.csrf // empty')"
    [[ -n "$CSRF" ]] || die "login: no CSRF token"
}

post() { "${CURL[@]}" -H "X-CSRF-Token: $CSRF" -X POST "$@"; }

running_slot()   { "${CURL[@]}" "$BASE/updates/slots" | jq -r '.[] | select(.running) | .slot'; }
slot_confirmed() { "${CURL[@]}" "$BASE/updates/slots" | jq -r --arg s "$1" '.[] | select(.slot==$s) | .confirmed'; }

wait_down() {
    local t=0
    while "${CURL[@]}" --max-time 3 -o /dev/null "$BASE/auth/whoami" 2>/dev/null; do
        sleep 1; t=$((t+1)); ((t < 120)) || die "$1: device never went down"
    done
}

wait_up() {
    local t=0
    until "${CURL[@]}" --max-time 3 -o /dev/null "$BASE/auth/whoami" 2>/dev/null; do
        sleep 5; t=$((t+5)); ((t < TIMEOUT)) || die "$1: device not back within ${TIMEOUT}s"
    done
    login
}

install_bundle() {
    post -H 'Content-Type: application/octet-stream' --data-binary "@${HIL_SWU}" \
        "$BASE/updates/upload?name=hil-$(date +%s).swu" | jq -e '.reboot_to_apply == true' >/dev/null \
        || die "$1: install did not reach reboot_to_apply"
}

step "login + baseline"
login
BEFORE="$(running_slot)"
[[ -n "$BEFORE" ]] || die "baseline: no running slot reported"
step "running slot: $BEFORE"

step "1/3 update: install $(basename "$HIL_SWU") to the inactive slot"
install_bundle update
post "$BASE/updates/reboot-to-apply" >/dev/null || true
wait_down update
wait_up update
AFTER="$(running_slot)"
[[ "$AFTER" != "$BEFORE" ]] || die "update: still on slot $BEFORE after reboot-to-apply"
step "now running slot $AFTER"

step "2/3 confirm"
if [[ "${HIL_MANUAL_CONFIRM:-0}" == 1 ]]; then
    post "$BASE/updates/confirm" >/dev/null || die "confirm: /updates/confirm refused"
fi
t=0
until [[ "$(slot_confirmed "$AFTER")" == true ]]; do
    sleep 5; t=$((t+5)); ((t < TIMEOUT)) || die "confirm: slot $AFTER never confirmed"
done
step "slot $AFTER confirmed"

if [[ "${HIL_SKIP_ROLLBACK:-0}" == 1 ]]; then
    step "3/3 rollback skipped (HIL_SKIP_ROLLBACK=1)"; exit 0
fi
: "${HIL_POWER_CYCLE:?HIL_POWER_CYCLE is required for the rollback step}"

step "3/3 rollback: install again, cut power during tryboot"
install_bundle rollback
post "$BASE/updates/reboot-to-apply" >/dev/null || true
wait_down rollback
# The device is in firmware/kernel on the one-shot tryboot slot: cut power
# before userspace's health gate can confirm it.
bash -c "$HIL_POWER_CYCLE" || die "rollback: power-cycle command failed"
wait_up rollback
FINAL="$(running_slot)"
[[ "$FINAL" == "$AFTER" ]] || die "rollback: expected fallback to $AFTER, running $FINAL"
[[ "$(slot_confirmed "$FINAL")" == true ]] || die "rollback: fallback slot $FINAL not confirmed"
step "fell back to confirmed slot $FINAL — PASS"
