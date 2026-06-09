# M5: Kernel/DTB in OTA Payload - Board Specific

**Severity:** Medium  
**Category:** Functionality  
**Created:** 2026-06-08

## Problem

Kernel and DTB inclusion in OTA payload is hardcoded for RPi5 and may not work for other board types.

## Evidence

### Files
- `Makefile` (lines 277-287)
- `meta/meta-acadia/swupdate/sw-description`
- `kas/boards/*.yaml` (all board configs)

### Issues
1. **Makefile lines 277-287**: Hardcoded RPi5 filenames:
   ```bash
   KERNEL := $(shell find ... -name "kernel_2712.img" ...)
   DTB := $(shell find ... -name "bcm2712-rpi-5-b.dtb" ...)
   ```
   
   This will not find files for other boards that use different kernel filenames:
   - RPi4: `kernel7l.img` or `kernel8.img`
   - RPi3: `kernel7.img` or `kernel7l.img`
   - RPi2: `kernel7.img`
   - RPi1: `kernel.img`
   - RPi0: `kernel.img`

2. **sw-description**: Only defines RPi5 kernel/DTB handlers

3. **Board configs**: Most boards don't have WKS_FILE override, so they use standard WKS which may not include A/B OTA

## Impact

- OTA update may fail on non-RPi5 boards
- Different boards need different kernel filenames in OTA payload
- Missing support for kernel/DTB updates on older boards

## Recommendation

1. **Make kernel/DTB copying conditional on board type** in `Makefile`:
   ```bash
   # Detect board by MACHINE variable or pattern matching
   case "$(MACHINE)" in
       raspberrypi5)
           KERNEL_PATTERN="kernel_2712.img"
           DTB_PATTERN="bcm2712-rpi-5-b.dtb"
           ;;
       raspberrypi4-64|raspberrypi4)
           KERNEL_PATTERN="kernel7l.img"
           DTB_PATTERN="bcm2711-rpi-4-b.dtb"
           ;;
       raspberrypi3-64|raspberrypi3)
           KERNEL_PATTERN="kernel7.img"
           DTB_PATTERN="bcm2837-rpi3-b.dtb"
           ;;
       raspberrypi2)
           KERNEL_PATTERN="kernel7.img"
           DTB_PATTERN="bcm2836-rpi2-b.dtb"
           ;;
       raspberrypi1|raspberrypi0*)
           KERNEL_PATTERN="kernel.img"
           DTB_PATTERN="bcm2835-rpi-b.dtb"
           ;;
   esac
   ```

2. **Document which boards support kernel/DTB OTA** vs those that don't:
   - RPi5/CM5: Yes (new mechanism with A/B)
   - RPi4/3/2/1/0: No (standard single-slot, kernel in /boot)
   - CM1/CM3: Verify

3. **Test with multiple board types** to ensure OTA works correctly

## References

- `Makefile:277-287`
- `meta/meta-acadia/swupdate/sw-description`
