# H3: Kernel/DTB Handling in OTA Updates

**Severity:** High  
**Category:** Stability / Functionality  
**Created:** 2026-06-08

## Problem

Kernel and DTB handling in OTA updates is complex and may not work for all board types. The current implementation is RPi5-specific and may fail on other boards.

## Evidence

### Files
- `meta/meta-acadia/swupdate/sw-description`
- `meta/meta-acadia/swupdate/pre-install.sh`
- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/post-install.sh`
- `Makefile` (lines 277-287)

### Issues
1. **Makefile lines 277-287**: Only looks for RPi5-specific files:
   - `kernel_2712.img` (RPi5 kernel)
   - `bcm2712-rpi-5-b.dtb` (RPi5 DTB)
   
   This may not work for other boards that use different kernel filenames.

2. **pre-install.sh lines 36-42**: Backs up kernel/DTB for rollback, but if any handler fails, rollback may be inconsistent.

3. **sw-description**: Defines kernel/DTB handlers (lines 29-38) but these are specific to RPi5.

4. **post-install.sh**: Assumes specific filenames exist on /boot.

## Impact

- OTA update may fail on non-RPi5 boards
- Kernel/DTB rollback may be inconsistent if handlers fail
- Board-specific differences are not handled

## Recommendation

1. **Make kernel/DTB copying conditional on board type** in `Makefile`:
   ```bash
   # Check which board and use appropriate filenames
   case "$(MACHINE)" in
       raspberrypi5)
           KERNEL_PATTERN="kernel_2712.img"
           DTB_PATTERN="bcm2712-rpi-5-b.dtb"
           ;;
       raspberrypi4-64)
           KERNEL_PATTERN="kernel7l.img"
           DTB_PATTERN="bcm2711-rpi-4-b.dtb"
           ;;
       # ... other boards
   esac
   ```

2. **Add error handling** for cases where kernel/DTB are missing:
   ```bash
   [ -n "$(KERNEL)" ] && cp "$(KERNEL)" "$(BUILD_DIR)/swu/kernel_2712.img" || \
       { echo "WARNING: kernel not found"; }
   ```

3. **Document which boards require kernel/DTB** in OTA vs those that don't:
   - RPi5/CM5: Yes (new mechanism)
   - RPi4/3/2/1/0: No (existing mechanism)
   - CM1/CM3: Verify

4. **Test with boards that use different kernel filenames** (rpi4, rpi3, etc.)

## References

- `Makefile:277-287`
- `meta/meta-acadia/swupdate/pre-install.sh:36-42`
- `meta/meta-acadia/swupdate/sw-description:29-38`
