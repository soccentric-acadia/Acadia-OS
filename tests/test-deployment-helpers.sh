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
[[ "${FAIL_SCP:-0}" != 1 ]]
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

# A symlink to the actual host root disk must be rejected before prompting or
# calling privileged tools, rather than relying on the input path spelling.
export TEST_ROOT_SOURCE="$(findmnt -n -o SOURCE /)"
mapfile -t root_devices < <(lsblk -s -l -n -p -o NAME "$TEST_ROOT_SOURCE" 2>/dev/null)
root_disk="${root_devices[${#root_devices[@]} - 1]}"
export TEST_ROOT_DISK="$root_disk"
ln -s "$root_disk" "$fixtures/root-disk-alias"
if root_alias_output="$(
    printf 'this-must-not-be-read\n' |
        bash "$image_dir/flash-image.sh" "$fixtures/root-disk-alias" 2>&1
)"; then
    fail "expected root-disk alias to be rejected"
fi
grep -Fqx "ERROR: refusing to overwrite the host root disk: $root_disk" \
    <<<"$root_alias_output" || fail "root-disk alias was not rejected before confirmation"
[[ ! -e "$TEST_LOG" ]] || fail "root-disk rejection invoked a privileged command"

# Simulate a safe whole disk with command doubles. The real loop device only
# satisfies Bash's block-device check; doubles prevent any host I/O while
# asserting confirmation precedes bmaptool.
cat >"$fake_bin/lsblk" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *"-dn -o TYPE /dev/loop0"*) echo disk ;;
    *"-o NAME $TEST_ROOT_SOURCE"*) printf '%s\n%s\n' "$TEST_ROOT_SOURCE" "$TEST_ROOT_DISK" ;;
    *"-o NAME,SIZE,TYPE,MOUNTPOINTS /dev/loop0"*) echo "loop0 1G disk" ;;
    *"-lnpo NAME /dev/loop0"*) echo /dev/loop0 ;;
    *) exit 1 ;;
esac
EOF
cat >"$fake_bin/findmnt" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == *"-n -o SOURCE /"* ]] && { echo "$TEST_ROOT_SOURCE"; exit 0; }
exit 1
EOF
cat >"$fake_bin/bmaptool" <<'EOF'
#!/usr/bin/env bash
printf 'bmaptool %s\n' "$*" >>"$TEST_LOG"
EOF
cat >"$fake_bin/sync" <<'EOF'
#!/usr/bin/env bash
printf 'sync\n' >>"$TEST_LOG"
EOF
chmod +x "$fake_bin/lsblk" "$fake_bin/findmnt" "$fake_bin/bmaptool" "$fake_bin/sync"
: >"$TEST_LOG"
confirmation_pipe="$fixtures/confirmation"
flash_output="$fixtures/flash-output"
mkfifo "$confirmation_pipe"
exec 3<>"$confirmation_pipe"
bash "$image_dir/flash-image.sh" /dev/loop0 <"$confirmation_pipe" >"$flash_output" 2>&1 &
flash_pid=$!
for _ in {1..20}; do
    grep -Fq "Type the exact device path (/dev/loop0) to continue:" "$flash_output" && break
    sleep 0.1
done
grep -Fq "Type the exact device path (/dev/loop0) to continue:" "$flash_output" ||
    fail "flash helper did not prompt for confirmation"
[[ ! -s "$TEST_LOG" ]] || fail "flash helper wrote before confirmation"
printf '/dev/loop0\n' >&3
wait "$flash_pid"
exec 3>&-
grep -Fqx "bmaptool copy --bmap $image_dir/acadia.wic.bmap $image_dir/acadia.wic.bz2 /dev/loop0" \
    "$TEST_LOG" || fail "flash helper did not reach bmaptool after confirmation"
grep -Fqx "sync" "$TEST_LOG" || fail "flash helper did not complete its mocked sync"

# Restore system block-device tools before the remaining tests.
rm "$fake_bin/lsblk" "$fake_bin/findmnt" "$fake_bin/bmaptool" "$fake_bin/sync"

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

: >"$TEST_LOG"
expect_failure env FAIL_SCP=1 bash "$swu_dir/install-swu.sh" operator@rpi5.local
mapfile -t commands <"$TEST_LOG"
[[ ${#commands[@]} -eq 1 && "${commands[0]}" == *"scp "* ]] ||
    fail "failed SWU copy invoked SSH or did not report the copy attempt"

echo "PASS: deployment helper fixture tests"
