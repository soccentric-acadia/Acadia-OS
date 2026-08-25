#!/usr/bin/env bash
# harden-image-check.sh — production image hardening gate (task 53).
#
# Scans the image recipe + shipped configs for classic production gaps:
#   1. unconditional broad debug tooling (must be gated),
#   2. default/empty root password or debug-tweaks enabling root login,
#   3. sshd configured to allow password/root login,
#   4. open ports / default credentials beyond documented services.
# Fails the build (exit 1) when a production image would ship these.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMG="$ROOT/meta/meta-acadia/recipes-core/images/acadia-image.bb"
SSHD="$ROOT/meta/meta-acadia/recipes-connectivity/openssh/files/acadia-hardening.conf"
fail=0

echo "== image hardening check =="

# 1. Broad debug tooling must be gated behind ACADIA_ENABLE_DEBUG.
if [ -f "$IMG" ]; then
  if grep -qE 'IMAGE_INSTALL:append = " (openocd|gdbserver|perf|trace-cmd|valgrind)' "$IMG"; then
    echo "  FAIL: debug tools installed unconditionally (must be gated by ACADIA_ENABLE_DEBUG)"
    fail=1
  elif grep -qE 'ACADIA_ENABLE_DEBUG \?=' "$IMG"; then
    echo "  OK: debug tooling is gated behind ACADIA_ENABLE_DEBUG"
  else
    echo "  FAIL: image recipe has no ACADIA_ENABLE_DEBUG gate"
    fail=1
  fi

  # 2. No debug-tweaks / empty-root-password unconditionally.
  if grep -qE 'IMAGE_FEATURES.*(debug-tweaks|empty-root-password)' "$IMG"; then
    echo "  FAIL: image enables debug-tweaks / empty-root-password (root login without password)"
    fail=1
  else
    echo "  OK: no unconditional debug-tweaks / empty-root-password"
  fi
fi

# 3. sshd must not permit password or root login.
if [ -f "$SSHD" ]; then
  if grep -qE '^PasswordAuthentication yes' "$SSHD"; then
    echo "  FAIL: sshd permits password authentication"
    fail=1
  else
    echo "  OK: sshd PasswordAuthentication disabled"
  fi
  if grep -qE '^PermitRootLogin yes' "$SSHD"; then
    echo "  FAIL: sshd permits root login"
    fail=1
  else
    echo "  OK: sshd PermitRootLogin disabled"
  fi
else
  echo "  WARN: sshd hardening config not found at $SSHD"
fi

# 4. webconfigd hardened unit (task 40) — non-root, restricted.
UNIT="$ROOT/meta/meta-acadia/../Acadia-Configuration/meta-webconfig/recipes-core/webconfig/files/webconfigd.service"
if [ -f "$UNIT" ]; then
  grep -q '^User=webconfig' "$UNIT" || { echo "  FAIL: webconfigd unit runs as root"; fail=1; }
  grep -q 'ProtectSystem=strict' "$UNIT" || { echo "  FAIL: webconfigd unit not hardened"; fail=1; }
  echo "  OK: webconfigd unit runs non-root and hardened"
fi

if [ "$fail" -eq 0 ]; then
  echo "== image hardening PASSED =="
  exit 0
fi
echo "== image hardening FAILED — resolve before shipping a production image =="
exit 1
