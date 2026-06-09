# C1: A/B OTA Rollback Mechanism Incomplete

**Severity:** Critical  
**Category:** Stability / Reliability  
**Created:** 2026-06-08

## Problem

The A/B OTA rollback mechanism is partially implemented but incomplete. If an update fails, devices may not automatically roll back to the previous working slot.

## Evidence

### Files
- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/swupdate-bootcheck.sh`
- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/boot-watchdog.sh`
- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/post-install.sh`

### Issues
1. **swupdate-bootcheck.sh**: Only checks if `acadia-client.service` is active (lines 26-28), but doesn't verify the service is actually working correctly.

2. **post-install.sh**: Does NOT set an `upgrade_available` flag in U-Boot environment (line 44-47 only sets it if `fw_setenv` exists - which it won't on RPi5).

3. **boot-watchdog.sh**: Correctly decrements `tries_remaining` and rolls back when exhausted (lines 34-47), but doesn't verify kernel/DTB actually booted properly - it only decrements the counter on every boot.

4. **Dependency ordering**: `swupdate-bootcheck.service` runs `After=network-online.target acadia-client.service` (line 4), but the health check needs to complete BEFORE network services can be relied upon.

## Impact

A bad update can permanently brick the device without manual recovery. Users would need physical access to recover from a failed update.

## Recommendation

1. Implement proper rollback using RPi firmware's tryboot mechanism (if supported) or ensure all required components work together correctly.

2. Move health check to run BEFORE `network.target`, not after `acadia-client.service`:
   - Current: `After=network-online.target acadia-client.service`
   - Should be: `After=local-fs.target` with early execution

3. Add proper rollback using tryboot mechanism:
   - Set `postupdatecmd = "/sbin/reboot"` in swupdate.cfg (already done)
   - Ensure the tryboot mechanism is properly integrated with the RPi firmware bootloader
   - Verify kernel/DTB actually booted, not just that services started

## References

- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/swupdate-bootcheck.sh:26-28`
- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/boot-watchdog.sh:34-47`
- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/post-install.sh:44-47`
