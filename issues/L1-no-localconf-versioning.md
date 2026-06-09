# L1: No local.conf Versioning

**Severity:** Low  
**Category:** Build Configuration  
**Created:** 2026-06-08

## Problem

Build configuration versioning is not explicit - only `CONF_VERSION` is set without `LOCALCONF_VERSION`.

## Evidence

### Files
- `kas/common.yaml` (line 36)

### Issue
- `CONF_VERSION = "2"` is set (required by Poky)
- But no `LOCALCONF_VERSION` is set
- No way to track what version of configuration is being used

## Impact

- No way to track configuration version
- Difficult to determine if configuration has changed between builds
- No version control for configuration changes

## Recommendation

Add explicit configuration version tracking:

```yaml
# In kas/common.yaml
local_conf_header:
  base: |
    # ...
    CONF_VERSION = "2"
    LOCALCONF_VERSION = "1"
    
    # ... rest of config
```

Or use a version file:
```bash
# In kas/common.yaml or post-process script
echo "ACADIA_OS_CONFIG_VERSION=1" >> ${BUILD_DIR}/conf/local.conf
```

## References

- `kas/common.yaml:36`
