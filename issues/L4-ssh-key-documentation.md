# L4: SSH Key Generation Not Documented

**Severity:** Low  
**Category:** Documentation  
**Created:** 2026-06-08

## Problem

Users don't know how to set up SSH keys for the rpi user, despite documentation saying SSH key access only.

## Evidence

### Files
- `README.md` (mentions SSH key access only)
- `meta/meta-acadia/recipes-core/images/core-image-full-cmdline.bbappend` (locked user)

### Issue
- Documentation says SSH key access only
- But no instructions on how to inject SSH keys during image build
- Users don't know how to provision SSH keys

## Impact

- Users cannot enable SSH access
- Confusion about how to access the device

## Recommendation

Document how to add SSH keys via `IMAGE_INSTALL` or first-boot configuration:

### Option 1: Via BUILD_ENV (environment variables)
```bash
# In Makefile or kas configuration
BUILD_ENV += "SSH_PUBKEY='ssh-rsa AAAA... user@host'"
```

### Option 2: Via image bbappend
```bitbake
# In core-image-full-cmdline.bbappend or custom image
do_rootfs:append() {
    install -d ${IMAGE_ROOTFS}/home/rpi/.ssh
    echo "${SSH_PUBKEY}" > ${IMAGE_ROOTFS}/home/rpi/.ssh/authorized_keys
    chown -R rpi:rpi ${IMAGE_ROOTFS}/home/rpi/.ssh
}
```

### Option 3: Via first-boot script
```bash
# In rpi5-home-init.sh
if [ -f /run/init-ssh-key ]; then
    mkdir -p /home/rpi/.ssh
    echo "${SSH_PUBKEY}" > /home/rpi/.ssh/authorized_keys
    chown -R rpi:rpi /home/rpi/.ssh
    rm -f /run/init-ssh-key
fi
```

## References

- `README.md:10`
- `meta/meta-acadia/recipes-core/images/core-image-full-cmdline.bbappend:104`
