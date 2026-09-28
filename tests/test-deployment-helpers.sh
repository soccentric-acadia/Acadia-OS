#!/usr/bin/env bash
# Host-only tests for the helper scripts staged with release artifacts.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixtures="$(mktemp -d)"
trap 'rm -rf "$fixtures"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

expect_failure() {
    if "$@"; then
        fail "expected command to fail: $*"
    fi
}

fake_bin="$fixtures/bin"
mkdir -p "$fake_bin"
export TEST_LOG="$fixtures/commands.log"
export PATH="$fake_bin:$PATH"

cat >"$fake_bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"$TEST_LOG"
"$@"
EOF
cat >"$fake_bin/scp" <<'EOF'
#!/usr/bin/env bash
printf 'scp %s\n' "$*" >>"$TEST_LOG"
EOF
cat >"$fake_bin/ssh" <<'EOF'
#!/usr/bin/env bash
printf 'ssh %s\n' "$*" >>"$TEST_LOG"
EOF
chmod +x "$fake_bin/sudo" "$fake_bin/scp" "$fake_bin/ssh"

# The flash helper must fail before invoking privileged tools when its input
# is not a block device.
image_dir="$fixtures/image"
mkdir -p "$image_dir"
cp "$repo_root/scripts/flash-image.sh" "$image_dir/flash-image.sh"
touch "$image_dir/acadia.wic.bz2" "$image_dir/acadia.wic.bmap"
expect_failure bash "$image_dir/flash-image.sh" "$fixtures/not-a-device"
[[ ! -e "$TEST_LOG" ]] || fail "flash validation invoked a privileged command"

installer_dir="$fixtures/sdk"
mkdir -p "$installer_dir"
cp "$repo_root/scripts/install-sdk.sh" "$installer_dir/install-sdk.sh"
cat >"$installer_dir/acadia-sdk.sh" <<'EOF'
#!/usr/bin/env bash
printf 'sdk-installer %s\n' "$*" >>"$TEST_LOG"
EOF
chmod +x "$installer_dir/acadia-sdk.sh"
bash "$installer_dir/install-sdk.sh"
grep -Fqx "sdk-installer -d /tool" "$TEST_LOG" ||
    fail "SDK installer did not receive /tool"

: >"$TEST_LOG"
esdk_dir="$fixtures/esdk"
mkdir -p "$esdk_dir"
cp "$repo_root/scripts/install-esdk.sh" "$esdk_dir/install-esdk.sh"
cat >"$esdk_dir/acadia-ext-sdk.sh" <<'EOF'
#!/usr/bin/env bash
printf 'esdk-installer %s\n' "$*" >>"$TEST_LOG"
EOF
chmod +x "$esdk_dir/acadia-ext-sdk.sh"
bash "$esdk_dir/install-esdk.sh"
grep -Fqx "esdk-installer -d /tool" "$TEST_LOG" ||
    fail "eSDK installer did not receive /tool"

: >"$TEST_LOG"
swu_dir="$fixtures/swu"
mkdir -p "$swu_dir"
cp "$repo_root/scripts/install-swu.sh" "$swu_dir/install-swu.sh"
touch "$swu_dir/acadia.swu"
bash "$swu_dir/install-swu.sh" operator@rpi5.local
mapfile -t commands <"$TEST_LOG"
[[ "${commands[0]}" == *"scp "* && "${commands[1]}" == *"ssh "* ]] ||
    fail "SWU helper did not copy before remote installation"
[[ "${commands[1]}" == *"sudo swupdate -i /tmp/acadia.swu"* ]] ||
    fail "SWU helper did not invoke remote swupdate for the copied bundle"

echo "PASS: deployment helper fixture tests"

