#!/usr/bin/env bash
#
# check-image-packages.sh — static image-package resolvability gate (OS-003).
#
# Fails fast when an IMAGE_INSTALL package named by any acadia-image*.bb has no
# provider recipe visible in the local layer checkouts (meta-acadia plus the
# kas-cloned upstream layers under layers/). This catches typos and missing
# recipes BEFORE an expensive kas/bitbake build.
#
# A provider is any of:
#   - a recipe file  <pn>.bb  (or <pn>_<version>.bb) in a scanned layer
#   - a recipe's PROVIDES = "..." line
#   - a recipe's PACKAGES = "..." split-package names (e.g. webconfig-static
#     provided by webconfigd.bb)
#
# IMAGE_FEATURES tokens and variable references are not package names and are
# skipped via a known-token list.
#
# Exit codes:
#   0   every token resolves (or is a known non-package token)
#   1   at least one unresolvable package token

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

META_ACADIA="$ROOT/meta/meta-acadia"
UPSTREAM_ROOT="$ROOT/layers"
IMAGES_DIR="$META_ACADIA/recipes-core/images"

# IMAGE_FEATURES values and other non-package tokens.
KNOWN_NON_PACKAGES=(
  "ssh-server-openssh" "package-management" "tools-debug" "tools-profile"
  "tools-sdk" "tools-testapps" "ptest-pkgs" "dbg-pkgs" "dev-pkgs" "doc-pkgs"
  "read-only-rootfs" "stateless-rootfs" "allow-empty-password"
  "allow-root-login" "splash" "nfs-server" "postinst-logging" "hwcodecs"
  "weston" "image" "append"
)

declare -A PROVIDES

# Join backslash-newline continuations so multi-line PACKAGES lists parse.
join_continuations() {
  sed ':a;N;$!ba;s/\\\n/ /g' "$1"
}

add_provider() {
  local pn="$1"
  [ -n "$pn" ] || return 0
  PROVIDES["$pn"]=1
}

# Extract PACKAGES/PROVIDES names from joined text, expanding ${PN} to "$1".
extract_provider_names() {
  local pn="$1" text="$2"
  local line words word
  while IFS= read -r line; do
    words="${line#*\"}"
    words="${words%\"}"
    words="${words//\$\{PN\}/$pn}"
    for word in $words; do
      add_provider "$word"
    done
  done < <(printf '%s\n' "$text" | grep -E '^[[:space:]]*(PROVIDES|PACKAGES)' | grep '=')
}

scan_recipe_file() {
  local f="$1"
  local base pn
  base="$(basename "$f")"
  pn="${base%%_*}"
  pn="${pn%.bb}"
  add_provider "$pn"
  extract_provider_names "$pn" "$(join_continuations "$f")"
}

# .inc files share PACKAGES across the recipes that include them; expand
# ${PN} for each sibling .bb in the same directory (conservative).
scan_inc_file() {
  local f="$1"
  local dir pn
  dir="$(dirname "$f")"
  local text
  text="$(join_continuations "$f")"
  grep -qE '^[[:space:]]*(PROVIDES|PACKAGES).*=' <<< "$text" || return 0
  while IFS= read -r -d '' bb; do
    pn="$(basename "$bb")"
    pn="${pn%%_*}"
    extract_provider_names "$pn" "$text"
  done < <(find "$dir" -maxdepth 1 -name '*.bb' -type f -print0 2>/dev/null)
}

if [ ! -d "$META_ACADIA" ]; then
  echo "ERROR: meta-acadia not found at $META_ACADIA" >&2
  exit 1
fi

while IFS= read -r -d '' f; do scan_recipe_file "$f"; done \
  < <(find "$META_ACADIA" -name '*.bb' -type f -print0 2>/dev/null)

if [ -d "$UPSTREAM_ROOT" ]; then
  while IFS= read -r -d '' f; do scan_recipe_file "$f"; done \
    < <(find "$UPSTREAM_ROOT" -name '*.bb' -type f -print0 2>/dev/null)
  while IFS= read -r -d '' f; do scan_inc_file "$f"; done \
    < <(find "$UPSTREAM_ROOT" -name '*.inc' -type f -print0 2>/dev/null)
else
  echo "NOTE: upstream layers not cloned under layers/ — gate covers meta-acadia only" >&2
fi

echo "Provider map: ${#PROVIDES[@]} package names from meta-acadia + upstream layers"

shopt -s nullglob
images=("$IMAGES_DIR"/acadia-image*.bb)
shopt -u nullglob
if [ "${#images[@]}" -eq 0 ]; then
  echo "ERROR: no acadia-image*.bb found under $IMAGES_DIR" >&2
  exit 1
fi

fail=0
for img in "${images[@]}"; do
  name="$(basename "$img")"
  missing=""
  # IMAGE_INSTALL append/+=/= tokens only; :remove lines never need providers.
  # Override suffixes (:raspberrypi5 etc.) are stripped before tokenising.
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    skip=0
    for k in "${KNOWN_NON_PACKAGES[@]}"; do
      if [ "$tok" = "$k" ]; then skip=1; break; fi
    done
    [ "$skip" -eq 0 ] || continue
    [ -z "${PROVIDES[$tok]:-}" ] && missing+=" $tok"
  done < <(grep -E '^[[:space:]]*IMAGE_INSTALL' "$img" \
           | grep -vE 'IMAGE_INSTALL:remove' \
           | sed -E 's/^([[:space:]]*IMAGE_INSTALL)(:[A-Za-z0-9_-]+)*/\1/' \
           | sed 's/#.*$//' \
           | grep -oE '[a-z0-9][a-z0-9+.-]*' || true)

  if [ -n "$missing" ]; then
    echo "  FAIL: $name — no recipe found for:${missing}"
    fail=1
  else
    echo "  OK: $name — all IMAGE_INSTALL tokens resolve"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "ERROR: unresolvable image packages (missing recipes, or upstream layers not cloned under layers/)" >&2
  exit 1
fi

# ── Required-package gate (SB-3 / T-P03) ──────────────────────────────────
# Features the image ships MUST have their runtime binaries present. Each
# entry below is required to appear in at least one acadia image recipe AND
# to resolve to a provider recipe. Removing one from the image without
# updating this list fails the gate — the removal must be a conscious,
# reviewable decision, never a silent dependency drop.
#
# Deferred by T-P00e (NOT required, features hidden in v1): hostapd, dnsmasq
# (AP mode), linuxptp (PTP), wireguard-tools (WireGuard) — packaging one
# means adding it here in the same change.
REQUIRED_IMAGE_PACKAGES=(
  polkit              # SB-2: D-Bus service control for webconfigd (T-P02)
  nftables            # SB-3: firewall applier drives nft (P-F01)
  chrony              # SB-3: GNSS time chain gpsd+chrony (P-D05)
  mosquitto-clients   # SB-3: alert delivery via mosquitto_pub (P-I07)
  curl                # SB-3: OTA/backup/HQ downloads (webconfigd shells out)
  ca-certificates     # TLS verification for the curl/HQ paths
  swupdate-client     # T-P26: WebConfig/HQ installs hand the bundle to the daemon IPC (P-K06)
)

for pkg in "${REQUIRED_IMAGE_PACKAGES[@]}"; do
  if [ -z "${PROVIDES[$pkg]:-}" ]; then
    echo "FAIL: required package '$pkg' has no provider recipe" >&2
    fail=1
    continue
  fi
  present=0
  for img in "${images[@]}"; do
    if grep -qE "(^|[[:space:]\"])${pkg}([[:space:]\"]|$)" <(grep -E '^[[:space:]]*IMAGE_INSTALL' "$img" | sed 's/#.*$//'); then
      present=1
      break
    fi
  done
  if [ "$present" -ne 1 ]; then
    echo "FAIL: required package '$pkg' resolves but is not installed by any acadia image" >&2
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "image package resolvability: FAIL" >&2
  exit 1
fi
echo "image package resolvability: OK (required set present)"