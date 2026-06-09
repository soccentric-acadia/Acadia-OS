# M3: SSH Password Authentication Not Explicitly Disabled

**Severity:** Medium  
**Category:** Security  
**Created:** 2026-06-08

## Problem

SSH hardening relies on include directive which may not be present in default sshd_config from Poky.

## Evidence

### Files
- `meta/meta-acadia/recipes-connectivity/openssh/files/acadia-hardening.conf`
- `meta/meta-acadia/recipes-connectivity/openssh/openssh_%.bbappend`

### Issues
1. **acadia-hardening.conf**: Correctly has:
   - `PasswordAuthentication no`
   - `ChallengeResponseAuthentication no`
   - `KbdInteractiveAuthentication no`
   - `PermitRootLogin no`
   - `AllowUsers rpi`

2. **But sshd_config must include** `/etc/ssh/sshd_config.d/*.conf` for these to take effect

3. **Default sshd_config from poky** may not include this include directive by default

## Impact

Password auth could be enabled if the Include directive is missing from sshd_config, negating the hardening efforts.

## Recommendation

1. **Verify the Include directive** is present in the main sshd_config:
   ```bash
   # Check in build:
   grep -r "Include" layers/poky/meta/recipes-connectivity/openssh/
   ```

2. **Consider creating a complete sshd_config file** rather than relying on include:
   ```bitbake
   # In openssh_%.bbappend or custom recipe
   do_install:append() {
       install -d ${D}${sysconfdir}/ssh
       install -m 0600 ${WORKDIR}/sshd_config ${D}${sysconfdir}/ssh/sshd_config
   }
   ```

3. **Add a test** to ensure password auth is truly disabled:
   ```bash
   # Add to tests or verify in build
   grep -E "^PasswordAuthentication (no|yes)" /etc/ssh/sshd_config
   ```

4. **Document the SSH security posture** clearly:
   - Password authentication: disabled
   - Key-based auth: enabled
   - Root login: disabled
   - AllowUsers: rpi (sudo group)

## References

- `meta/meta-acadia/recipes-connectivity/openssh/files/acadia-hardening.conf`
