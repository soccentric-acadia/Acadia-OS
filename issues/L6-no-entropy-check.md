# L6: No Entropy Check for Credential Generation

**Severity:** Low  
**Category:** Security  
**Created:** 2026-06-08

## Problem

First-boot password generation doesn't verify system has enough entropy before generating credentials.

## Evidence

### Files
- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/swupdate-webui-auth-init.sh` (line 17)

### Issue
```bash
PASSWORD=$(openssl rand -base64 12 | tr -d '=+/' | head -c 12)
```

This uses `openssl rand` which reads from `/dev/urandom`. On systems with very low entropy:
- Passwords may be predictable
- Cryptographic weaknesses possible

## Impact

Weak credentials may be generated on systems with low entropy, especially headless devices without much entropy sources.

## Recommendation

Add entropy check before credential generation:

```bash
#!/bin/bash
# swupdate-webui-auth-init.sh

# Check entropy quality
ENTROPY_AVAILABLE=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
if [ "$ENTROPY_AVAILABLE" -lt 100 ]; then
    echo "[swupdate-webui] WARNING: Low entropy available ($ENTROPY_AVAILABLE bits)" >&2
    echo "[swupdate-webui] Consider adding entropy sources (hwrandom, haveged)" >&2
    # Continue but with warning
fi

# Generate password
PASSWORD=$(openssl rand -base64 12 | tr -d '=+/' | head -c 12)
```

Or use `/dev/random` with timeout:
```bash
# Wait up to 10 seconds for sufficient entropy
timeout 10 sh -c 'cat /dev/random | tr -dc a-zA-Z0-9 | head -c 12' || \
    echo "[swupdate-webui] Failed to generate secure password" >&2
```

## References

- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/swupdate-webui-auth-init.sh:17`
