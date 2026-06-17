SUMMARY = "Acadia OS — production image for Raspberry Pi 5"
DESCRIPTION = "Full image with A/B OTA, gRPC/Protobuf, Acadia-HAL, \
               Acadia-Client daemon, and hardware interface tooling."
HOMEPAGE = "https://github.com/SiliconCentric/Acadia-OS"
LICENSE = "MIT"

# Base on core-image-full-cmdline (provides bash, sshd-openssh,
# package-management, base IMAGE_INSTALL framework).  The previous
# version inherited bare core-image, which gave a smaller image but
# one that did not match the operator-visible feature set documented
# in CLAUDE.md / README.md.  Issues #25 and #45: the two image recipes
# (acadia-image.bb and core-image-full-cmdline.bbappend) had
# divergent bases.  This is the canonical fix — both recipes now
# share the same Yocto base; the bbappend-style deltas go into
# this single recipe.
#
# NOTE: core-image-full-cmdline is an *image recipe*, not a bbclass,
# so it must be pulled in with `require` (not `inherit`).
require recipes-extended/images/core-image-full-cmdline.bb
IMAGE_FEATURES += "ssh-server-openssh"

# OTA / swupdate
IMAGE_INSTALL:append = " swupdate swupdate-www rpi5-swupdate-config"

# Home partition init
IMAGE_INSTALL:append = " rpi5-home-init"

# Connectivity
# rpi5-connectivity already pulls wpa-supplicant + bluez5 via RDEPENDS
# (issue #53); list only the tools the user might use directly.
IMAGE_INSTALL:append = " \
    rpi5-connectivity iw rfkill bluez5-dev \
"

# gRPC + Protobuf (NO compiler on device — M5)
IMAGE_INSTALL:append = " \
    protobuf protobuf-lite grpc \
    python3-grpcio python3-protobuf sudo \
"

# Hardware interface tools
IMAGE_INSTALL:append = " \
    i2c-tools python3-smbus python3-smbus2 \
    spitools python3-spidev \
    libgpiod libgpiod-tools python3-gpiod \
    picocom minicom python3-pyserial \
    usbutils pciutils nvme-cli sg3-utils hdparm mtd-utils \
    can-utils \
    lshw ethtool devmem2 cpupower watchdog sysstat iotop strace \
    v4l-utils evtest python3-periphery vim \
"

# Acadia stack
# NOTE: acadia-client is excluded until the upstream repo exists and SRCREV is
# pinned. Add it back once available: acadia-client acadia-data-init
IMAGE_INSTALL:append = " acadia-hal acadia-services"

# Operator account — locked, SSH-key access only
# Issue #102: use -M (--no-create-home) because p4 (/home) is
# recreated by rpi5-home-init.sh on first boot.  useradd -m would
# create /home/rpi on the volatile rootfs, which is then hidden
# by the persistent mount at /home.
inherit extrausers
EXTRA_USERS_PARAMS = "\
    useradd -M -s /bin/bash -G sudo rpi; \
    usermod -L rpi; \
"
