# L2: Missing Kernel Config Fragments

**Severity:** Low  
**Category:** Build Configuration  
**Created:** 2026-06-08

## Problem

No explicit control over which kernel drivers are included - only `SRCREV` is pinned.

## Evidence

### Files
- `meta/meta-acadia/recipes-kernel/linux/linux-raspberrypi_6.6.bbappend`

### Issue
- Only `SRCREV_machine` is pinned
- No kernel config fragments added
- Drivers may be included by default in RPi kernel but not guaranteed

## Impact

- No explicit control over kernel drivers
- Drivers may change between kernel versions
- Missing drivers on rebuild if default config changes

## Recommendation

Add config fragments to ensure specific drivers are compiled:

```bitbake
# In linux-raspberrypi_6.6.bbappend
FILESEXTRAPATHS_prepend := "${THISDIR}/files:"
SRC_URI += " \
    file://0001-use-64-bit-time_t.patch \
    file://i2c.cfg \
    file://spi.cfg \
    file://gpio.cfg \
    file://can.cfg \
"
```

Config fragment examples:
```
# i2c.cfg
CONFIG_I2C_BCM2835=m
CONFIG_I2C_DEV=m

# spi.cfg
CONFIG_SPI_BCM2835=m
CONFIG_SPI_BCM2835AUX=m
CONFIG_SPI_DEV=m

# gpio.cfg
CONFIG_GPIO_BCM2835=m
CONFIG_GPIO_SYSFS=y
```

## References

- `meta/meta-acadia/recipes-kernel/linux/linux-raspberrypi_6.6.bbappend`
