# C2: No SWUpdate Image Signing

**Severity:** Critical  
**Category:** Security  
**Created:** 2026-06-08

## Problem

SWUpdate packages are unsigned by default - any attacker on the network can push malicious updates to any device.

## Evidence

### Files
- `Makefile` (lines 296-312)
- `meta/meta-acadia/swupdate/swupdate.cfg`
- `meta/meta-acadia/recipes-swupdate/swupdate_%.bbappend`

### Issues
1. **Makefile lines 296-312**: The signing check only warns but continues if no private key found:
   ```bash
   if [ -f "..." ]; then
       echo "Signing sw-description with RSA-4096 ..."
       # ... sign ...
   else
       echo "WARNING: No private key found — packing UNSIGNED .swu"
       # ... continues WITHOUT SIGNING ...
   fi
   ```

2. **swupdate.cfg**: Has no `signingalg` or key configuration - only `globals`, `identify`, and `download` sections are present.

3. **swupdate_%.bbappend**: References a config fragment but it's not in the repository.

## Impact

Any attacker on the network can push malicious updates to any device. This is a severe security vulnerability that could allow complete device compromise.

## Recommendation

1. **Generate RSA-4096 keypair** (one-time, keep private key offline):
   ```bash
   openssl genrsa -out swupdate-priv.pem 4096
   openssl req -new -x509 -key swupdate-priv.pem -out swupdate-cert.pem
   ```

2. **Commit only public key** to repository at `meta/meta-acadia/swupdate/keys/public.pem`

3. **Add to swupdate.cfg**:
   ```
   globals: {
       signingalg = "RSA-PKCS1-v1_5";
       # or for CMS: sigtype = "cms"; certfile = "...";
   }
   ```

4. **Modify `make swu` to FAIL if no private key exists** (not just warn)

5. **Configure SWUPDATE_SIGNING** and **SWUPDATE_PRIVATE_KEY** in `swupdate_%.bbappend`

6. **Document the signing process** in the README for build reproducibility

## References

- `Makefile:296-312`
- `meta/meta-acadia/swupdate/swupdate.cfg`
- `meta/meta-acadia/recipes-swupdate/swupdate_%.bbappend`
