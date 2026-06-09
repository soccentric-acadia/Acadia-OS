# C4: Default SSH Password in Documentation

**Severity:** Critical  
**Category:** Security  
**Created:** 2026-06-08

## Problem

Documentation shows default password 'rpi' for user 'rpi' which contradicts the locked user implementation. This creates confusion about the actual security posture.

## Evidence

### Files
- `README.md` (line 308)
- `meta/meta-acadia/recipes-core/images/core-image-full-cmdline.bbappend` (lines 102-110)
- `meta/meta-acadia/recipes-connectivity/openssh/files/acadia-hardening.conf`

### Issues
1. **README.md line 308**: Documents `Username: **rpi** / Password: **rpi**`

2. **core-image-full-cmdline.bbappend lines 107-110**: Shows:
   ```bitbake
   EXTRA_USERS_PARAMS = "\
       useradd -m -s /bin/bash -G sudo rpi; \
       usermod -L rpi; \
   "
   ```
   The `usermod -L rpi` locks the user, but the README contradicts this.

3. **core-image-full-cmdline.bbappend line 103**: Comment says "LOCKED (no password). SSH key access only." but README says password is 'rpi'

4. **openssh/acadia-hardening.conf**: Correctly has `PasswordAuthentication no` and other hardening settings.

## Impact

Any device running this image has a known default password that grants root access (user 'rpi' is in sudo group). This is a security vulnerability if users follow the README documentation.

## Recommendation

1. **Update README.md** to match actual implementation:
   ```markdown
   # User account
   - Username: **rpi**
   - Password: **Locked** - SSH key access only
   - Member of the `sudo` group
   - Home directory on the persistent `/home` partition (p4)
   
   ## Adding SSH Keys
   To enable SSH access, add your public key to `/home/rpi/.ssh/authorized_keys` after flashing, or use first-boot configuration.
   ```

2. **Keep the locked user implementation** (usermod -L is correct)

3. **Ensure `PasswordAuthentication no`** is in sshd_config (verified in acadia-hardening.conf)

4. **Add documentation** on how to provision SSH keys at build time or first-boot

## References

- `README.md:308`
- `meta/meta-acadia/recipes-core/images/core-image-full-cmdline.bbappend:102-110`
- `meta/meta-acadia/recipes-connectivity/openssh/files/acadia-hardening.conf`
