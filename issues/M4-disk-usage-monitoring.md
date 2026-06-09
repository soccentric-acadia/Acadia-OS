# M4: Disk Usage Monitoring Not Documented

**Severity:** Medium  
**Category:** Documentation / Monitoring  
**Created:** 2026-06-08

## Problem

Disk usage monitoring exists but is not documented in the README or user-facing documentation.

## Evidence

### Files
- `meta/meta-acadia/recipes-core/acadia-services/files/disk-usage-check.sh`
- `meta/meta-acadia/recipes-core/acadia-services/files/disk-usage-check.service`
- `meta/meta-acadia/recipes-core/acadia-services/files/disk-usage-check.timer`

### Issues
1. **disk-usage-check.sh**: Exists but no documentation on what it does or how to configure thresholds

2. **disk-usage-check.service**: Runs oneshot on boot

3. **disk-usage-check.timer**: Runs `OnBootSec=5min` and `OnUnitActiveSec=1h` - meaning:
   - First check 5 minutes after boot
   - Subsequent checks every 1 hour

4. **No documentation** on this feature in README.md or swupdate/README.md

## Impact

- Users don't know about disk usage monitoring
- No visibility on this important monitoring feature
- Users may not realize their system is being monitored

## Recommendation

1. **Add documentation** to README.md about disk usage monitoring:
   ```markdown
   ## Disk Usage Monitoring
   The system includes automatic disk usage monitoring that:
   - First check: 5 minutes after boot
   - Subsequent checks: Every 1 hour
   - Threshold: Warns when filesystems exceed 80% usage
   
   Logs are written to journald. Check with: `journalctl -u disk-usage-check`
   ```

2. **Document the threshold** in disk-usage-check.sh:
   - What threshold triggers warning?
   - How are warnings reported?

3. **Consider making threshold configurable** via local.conf or a config file:
   ```yaml
   local_conf_header:
     monitoring: |
       DISK_USAGE_THRESHOLD = "80"
   ```

4. **Document log location** and how to check status

## References

- `meta/meta-acadia/recipes-core/acadia-services/files/disk-usage-check.sh`
- `meta/meta-acadia/recipes-core/acadia-services/files/disk-usage-check.timer`
