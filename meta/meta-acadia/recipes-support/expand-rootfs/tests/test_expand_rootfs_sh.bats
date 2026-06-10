#!/usr/bin/env bats
# test_expand_rootfs_sh.bats — regression test for the
# expand-rootfs.sh device-resolution logic.
#
# Issue #42: the previous expand-rootfs.sh regex-parsed the
# device name with two patterns:
#   ^(mmcblk[0-9]+)p([0-9]+)$  (correct for mmcblk0p2)
#   ^([a-z]+)([0-9]+)$         (broken fallback)
# The second pattern captured (nvme, 0) for nvme0n1p2, so
# `parted /dev/nvme resizepart 0 100%` would either fail or
# target the wrong device.  The fix uses lsblk + /sys/class/block
# to derive parent disk and partition number — same pattern as
# rpi5-home-init.sh, portable across mmcblk/nvme/sd/vd.
#
# We test the device-resolution step in isolation: extract the
# assignment to DISK_NAME and PART_NUM, run the snippet with
# stubbed findmnt/lsblk/sysfs, and assert the variables hold
# the right values.  We do NOT call parted (privileged, no
# loopback partition table in CI) — that's beyond the scope
# of the bug, which was strictly in the regex parser.

setup() {
    SUT="${BATS_TEST_DIRNAME}/../files/expand-rootfs.sh"
    [ -f "${SUT}" ] || skip "expand-rootfs.sh not found at ${SUT}"
}

@test "expand-rootfs.sh: uses lsblk -ndo PKNAME, not a regex on the dev name" {
    # The fix replaces the regex-based device parsing with
    # `lsblk -ndo PKNAME`.  Anchor on the literal `lsblk` call
    # so a regression to the regex pattern is caught.
    grep -qE '^[[:space:]]*DISK_NAME=\$\(lsblk[[:space:]]+(-ndo|-no)[[:space:]]+PKNAME' "${SUT}"
}

@test "expand-rootfs.sh: reads partition number from /sys/class/block" {
    # The fix reads PART_NUM from /sys/class/block/<dev>/partition.
    # Anchor on the cat call to /sys/class/block so a regression
    # to `echo ${dev} | grep -o '[0-9]*$'` is caught.
    grep -qE '^[[:space:]]*PART_NUM=\$\(cat[[:space:]]+"/sys/class/block/' "${SUT}"
}

@test "expand-rootfs.sh: NO regex against ROOT_DEV_NAME for the disk" {
    # The old `[[ "$ROOT_DEV_NAME" =~ ^([a-z]+)([0-9]+)$ ]]` was
    # the broken fallback that captured (nvme, 0) for nvme0n1p2.
    # Anchor on `ROOT_DEV_NAME =~` so any regression to the
    # regex style is caught, even if the new code uses a
    # different regex.
    ! grep -qE 'ROOT_DEV_NAME[[:space:]]*=~' "${SUT}"
}

@test "expand-rootfs.sh: NO fallback to BASH_REMATCH (regex path gone)" {
    # The old code used ${BASH_REMATCH[1]} / ${BASH_REMATCH[2]}.
    # If neither is referenced, the regex parser is gone.
    ! grep -qE 'BASH_REMATCH\[' "${SUT}"
}

@test "expand-rootfs.sh: bails out cleanly if parent disk can't be determined" {
    # Defensive: when lsblk returns empty and /sys has no
    # partition file, the script should exit 1 with a clear
    # error message, not silently default.
    grep -qE 'cannot determine parent disk' "${SUT}"
}

# ── Behaviour tests ──────────────────────────────────────────────────────
# Run the actual device-resolution snippet from expand-rootfs.sh
# in a subshell with stubbed findmnt/lsblk and a fake /sys/class/block.
# The snippet is a literal copy of lines 14-29; if the production
# code changes, this test must change in the same commit.

resolve_disk_and_part() {
    # Mirror lines 14-29 of expand-rootfs.sh.  If the production
    # code changes, update this block in the same commit.
    ROOT_DEV=$(findmnt -n -o SOURCE /)
    ROOT_DEV_NAME="${ROOT_DEV#/dev/}"

    DISK_NAME=$(lsblk -ndo PKNAME "${ROOT_DEV}" 2>/dev/null || true)
    PART_NUM=$(cat "/sys/class/block/${ROOT_DEV_NAME}/partition" 2>/dev/null || true)

    if [[ -z "${DISK_NAME}" || -z "${PART_NUM}" ]]; then
        echo "expand-rootfs: cannot determine parent disk for '$ROOT_DEV', aborting." >&2
        return 1
    fi
}

# Helper: set up a stub BIN with findmnt/lsblk/cat that target a
# fake /sys/class/block, plus a sysfs directory tree under SYS.
# Usage: setup_stubs "<root_dev>" "<lsblk_pkname>" "<partition_num>"
setup_stubs() {
    local root_dev="$1" pkname="$2" partnum="$3"
    BIN=$(mktemp -d)
    SYS=$(mktemp -d)
    export PATH="${BIN}:${PATH}"

    mkdir -p "${SYS}/class/block/${root_dev#/dev/}"
    echo "${partnum}" > "${SYS}/class/block/${root_dev#/dev/}/partition"

    cat > "${BIN}/findmnt" <<STUB
#!/bin/sh
echo "${root_dev}"
STUB
    chmod +x "${BIN}/findmnt"

    cat > "${BIN}/lsblk" <<STUB
#!/bin/sh
[ -n "${pkname}" ] && echo "${pkname}"
STUB
    chmod +x "${BIN}/lsblk"

    # Stub cat that forwards /sys/class/block/* paths to our fake
    # sysfs and otherwise delegates to the real cat.
    # Stub cat: rewrite /sys/class/block/<dev> requests to our fake
    # sysfs at ${SYS}/class/block/<dev>.  The production script calls
    # cat with the literal `/sys/class/block/...` path (not the temp
    # SYS path), so the stub must translate on the way in.  Otherwise
    # it falls through to the real cat, which fails (no such file in CI).
    REAL_CAT=$(command -v cat)
    cat > "${BIN}/cat" <<STUB
#!/bin/sh
for arg in "\$@"; do
    case "\${arg}" in
        /sys/class/block/*)
            ${REAL_CAT} "${SYS}\${arg#/sys}" 2>/dev/null
            exit \$? ;;
    esac
done
exec ${REAL_CAT} "\$@"
STUB
    chmod +x "${BIN}/cat"
}

teardown_stubs() {
    rm -rf "${BIN}" "${SYS}"
}

@test "expand-rootfs.sh: mmcblk0p2 resolves to disk=mmcblk0 part=2" {
    setup_stubs "/dev/mmcblk0p2" "mmcblk0" "2"

    run bash -c "
        export PATH='${BIN}:\${PATH}'
        $(declare -f resolve_disk_and_part)
        resolve_disk_and_part && echo \"DISK=\${DISK_NAME} PART=\${PART_NUM}\"
    "
    teardown_stubs
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"DISK=mmcblk0 PART=2"* ]]
}

@test "expand-rootfs.sh: nvme0n1p2 resolves to disk=nvme0n1 part=2 (issue #42)" {
    setup_stubs "/dev/nvme0n1p2" "nvme0n1" "2"

    run bash -c "
        export PATH='${BIN}:\${PATH}'
        $(declare -f resolve_disk_and_part)
        resolve_disk_and_part && echo \"DISK=\${DISK_NAME} PART=\${PART_NUM}\"
    "
    teardown_stubs
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"DISK=nvme0n1 PART=2"* ]]
}

@test "expand-rootfs.sh: sda2 resolves to disk=sda part=2 (USB boot)" {
    setup_stubs "/dev/sda2" "sda" "2"

    run bash -c "
        export PATH='${BIN}:\${PATH}'
        $(declare -f resolve_disk_and_part)
        resolve_disk_and_part && echo \"DISK=\${DISK_NAME} PART=\${PART_NUM}\"
    "
    teardown_stubs
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"DISK=sda PART=2"* ]]
}

@test "expand-rootfs.sh: lsblk empty + no sysfs file → exit 1 with clear error" {
    # lsblk returns empty AND there's no sysfs partition file —
    # the resolution must fail loudly.
    setup_stubs "/dev/nvme0n1p2" "" ""

    run bash -c "
        export PATH='${BIN}:\${PATH}'
        $(declare -f resolve_disk_and_part)
        resolve_disk_and_part
    "
    teardown_stubs
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"cannot determine parent disk"* ]]
}
