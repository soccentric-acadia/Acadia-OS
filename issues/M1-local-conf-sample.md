# M1: Missing local.conf.sample

**Severity:** Medium  
**Category:** Documentation  
**Created:** 2026-06-08

## Problem

No standalone `local.conf.sample` exists for new developers to understand the build configuration.

## Evidence

### Files
- Project root directory

### Issue
- KAS generates `build/conf/local.conf` on each run, but no standalone `local.conf.sample` exists
- The audit report notes this as M2 in the comprehensive audit

## Impact

- New developers unfamiliar with KAS cannot easily understand or replicate builds
- Configuration options are not clearly documented

## Recommendation

Add `local.conf.sample` to project root with comments explaining each configuration option:

```yaml
# local.conf.sample - Example configuration for Acadia-OS builds
# Copy this to kas/common.yaml or build/conf/local.conf

local_conf_header:
  base: |
    # Init manager
    INIT_MANAGER = "systemd"

    # SD card image output
    IMAGE_FSTYPES = "wic.bz2 wic.bmap ext4"

    # Raspberry Pi settings
    ENABLE_UART = "1"
    GPU_MEM     = "128"

    # Accept proprietary firmware licence
    LICENSE_FLAGS_ACCEPTED:append = " synaptics-killswitch"

    # Shared caches (bind-mounted by Docker)
    DL_DIR     ?= "${TOPDIR}/../downloads"
    SSTATE_DIR ?= "${TOPDIR}/../sstate-cache"

    # Required by Poky sanity checks
    CONF_VERSION = "2"

    # U-Boot configuration for A/B OTA (RPi5/CM5)
    UBOOT_ENV_SUFFIX = "scr"
    UBOOT_ENV = "boot"
    MACHINE_FEATURES:append = " u-boot"
    RPI_USE_U_BOOT = "1"
```

## References

- N/A - this is a documentation issue
