# L7: U-Boot Configuration Questionable for RPi5

**Severity:** Low  
**Category:** Build Configuration  
**Created:** 2026-06-08

## Problem

U-Boot configuration settings in kas/common.yaml may not apply to RPi5, which uses Broadcom SoC firmware, not U-Boot as primary bootloader.

## Evidence

### Files
- `kas/common.yaml` (lines 38-47)

### Issue
```yaml
# CM-13 OTA rollback/A-B redundancy
UBOOT_ENV_SUFFIX = "scr"
UBOOT_ENV = "boot"
MACHINE_FEATURES:append = " u-boot"
RPI_USE_U_BOOT = "1"

# Enable bootcount in U-Boot
UBOOT_MACHINE = "rpi_arm64_defconfig"
EXTRA_IMAGEDEPENDS += "u-boot"
IMAGE_INSTALL:append = " u-boot-fw-utils"
```

Issues:
1. **RPi5 uses RPi firmware bootloader**, not U-Boot as primary
2. U-Boot may only be used for secondary stage (if at all)
3. U-Boot environment variables may not be applicable

## Impact

U-Boot configuration may not be appropriate for RPi5/CM5. This could cause:
- Build warnings or errors
- Unexpected behavior at runtime
- Unnecessary U-Boot dependency

## Recommendation

1. **Review RPi5 bootloader architecture**:
   - Primary: RPi firmware (broadcom firmware)
   - Secondary: U-Boot (if configured)

2. **Condition U-Boot settings** on board type:
   ```yaml
   local_conf_header:
     rpi5_ua: |
       # U-Boot for A/B OTA on RPi5/CM5 only
       UBOOT_ENV_SUFFIX = "scr"
       UBOOT_ENV = "boot"
       MACHINE_FEATURES:append = " u-boot"
       RPI_USE_U_BOOT = "1"
       UBOOT_MACHINE = "rpi_arm64_defconfig"
       EXTRA_IMAGEDEPENDS += "u-boot"
       IMAGE_INSTALL:append = " u-boot-fw-utils"
   ```

3. **Or use board-specific yaml files**:
   - `kas/boards/rpi5.yaml`: Include U-Boot config
   - `kas/boards/rpi4-64.yaml`: No U-Boot config (uses RPi firmware)

4. **Test on RPi5** to verify U-Boot configuration works correctly

## References

- `kas/common.yaml:38-47`
