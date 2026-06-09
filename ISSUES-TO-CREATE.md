# GitHub Issues to Create for Acadia-OS

This document contains the 19 issues identified during the deep review of Acadia-OS.

## Critical Issues

### 1. C1: A/B OTA Rollback Mechanism Incomplete
**Severity:** Critical  
**Labels:** bug, stability, security

**Description:**
The A/B OTA rollback mechanism is partially implemented but incomplete. If an update fails, devices may not automatically roll back to the previous working slot.

**Evidence:**
- `swupdate-bootcheck.sh`: Only checks if `acadia-client.service` is active, doesn't verify the service is actually working correctly
- `post-install.sh`: Does NOT set an `upgrade_available` flag in U-Boot environment
- `boot-watchdog.sh`: Only decrements `tries_remaining`, doesn't verify kernel/DTB actually booted properly
- Dependency ordering issue: `swupdate-bootcheck.service` runs after `network-online.target acadia-client.service` but health check needs to complete BEFORE network services

**Recommendation:**
1. Implement proper rollback using RPi firmware's tryboot mechanism
2. Move health check to run BEFORE `network.target`
3. Add proper rollback using tryboot mechanism

---

### 2. C2: No SWUpdate Image Signing
**Severity:** Critical  
**Labels:** security, bug

**Description:**
SWUpdate packages are unsigned by default - any attacker on the network can push malicious updates to any device.

**Evidence:**
- Makefile lines 296-312: Only warns but continues if no private key found
- swupdate.cfg: Has no `signingalg` or key configuration
- swupdate_%.bbappend: References a config fragment but it's not in the repository

**Recommendation:**
1. Generate RSA-4096 keypair and store private key in CI secrets
2. Commit only public key to repository
3. Modify `make swu` to FAIL if no private key exists
4. Add signing configuration to swupdate.cfg

---

### 3. C3: Acadia-Client Excluded from Image
**Severity:** Critical  
**Labels:** bug, functionality

**Description:**
The primary application daemon (acadia-client) is not included in the OS image.

**Evidence:**
- core-image-full-cmdline.bbappend line 99: Has comment `# NOTE: acadia-client excluded until upstream repo is available`
- acadia-image.bb line 44: Same exclusion
- acadia-client_git.bb uses hardcoded SRCREV placeholder

**Recommendation:**
1. Remove the acadia-client exclusion comment and add to IMAGE_INSTALL
2. Update acadia-client_git.bb to use proper pinned SRCREV when upstream repo is available
3. Ensure proper systemd dependency ordering between acadia-client and swupdate-bootcheck

---

### 4. C4: Default SSH Password in Documentation Contradicts Locked User
**Severity:** Critical  
**Labels:** security, documentation

**Description:**
README.md documents a password 'rpi' for user 'rpi' which contradicts the locked user implementation in the code.

**Evidence:**
- README.md line 308: Documents `Username: **rpi** / Password: **rpi**`
- core-image-full-cmdline.bbappend: Shows user is locked with `usermod -L rpi`

**Recommendation:**
1. Update README.md to show "Password: Locked - SSH key access only"
2. Document how to provision SSH keys at build time or first-boot

---

## High Priority Issues

### 5. H1: Non-Reproducible Builds
**Severity:** High  
**Labels:** bug, build

**Description:**
Builds are not reproducible - external layer repos use HEAD or AUTOREV.

**Evidence:**
- poky.yaml, meta-openembedded.yaml, meta-swupdate.yaml: All use `commit: HEAD`
- acadia-hal_git.bb uses `SRCREV = "${AUTOREV}"`

**Recommendation:**
1. Pin all external layer repos to specific commit SHAs
2. Create a script to help pin layers

---

### 6. H2: SWUpdate Web UI Unauthenticated
**Severity:** High  
**Labels:** security, bug

**Description:**
SWUpdate web UI authentication is not enabled by default. Anyone on the network can push updates.

**Recommendation:**
1. Ensure swupdate-webui-auth-init.sh runs before swupdate.service
2. Add authentication configuration to swupdate.cfg
3. Add HTTPS/TLS support for web UI

---

### 7. H3: Kernel/DTB OTA Handling May Fail on Non-RPi5 Boards
**Severity:** High  
**Labels:** bug, functionality

**Description:**
Kernel and DTB handling in OTA updates is RPi5-specific and may not work for other boards.

**Recommendation:**
1. Make kernel/DTB copying conditional on board type in Makefile
2. Test with multiple board types
3. Document which boards support kernel/DTB OTA

---

## Medium Priority Issues

### 8. M1: Missing local.conf.sample
**Severity:** Medium  
**Labels:** documentation, good first issue

**Description:**
No standalone local.conf.sample exists for new developers.

**Recommendation:**
Add local.conf.sample to project root with comments explaining each configuration option.

---

### 9. M2: Inconsistent Partition Mount Point Documentation
**Severity:** Medium  
**Labels:** documentation, bug

**Description:**
WKS file says `/home`, README says `/data`. Documentation is inconsistent.

**Recommendation:**
Standardize on one mount point and update all references.

---

### 10. M3: SSH Password Authentication Not Explicitly Disabled
**Severity:** Medium  
**Labels:** security, bug

**Description:**
SSH hardening relies on include directive which may not be present in default sshd_config.

**Recommendation:**
1. Verify the Include directive is present in sshd_config
2. Consider creating a complete sshd_config file

---

### 11. M4: Disk Usage Monitoring Not Documented
**Severity:** Medium  
**Labels:** documentation

**Description:**
Disk usage monitoring exists but is not documented.

**Recommendation:**
Add documentation about disk usage monitoring to README.md.

---

### 12. M5: Kernel/DTB in OTA Payload - Board Specific
**Severity:** Medium  
**Labels:** bug, functionality

**Description:**
Kernel and DTB inclusion in OTA payload is hardcoded for RPi5.

**Recommendation:**
Make kernel/DTB copying conditional on board type in Makefile.

---

## Low Priority Issues

### 13. L1: No local.conf Versioning
**Severity:** Low  
**Labels:** build, enhancement

**Description:**
Build configuration versioning is not explicit.

**Recommendation:**
Add `LOCALCONF_VERSION` to track configuration version.

---

### 14. L2: Missing Kernel Config Fragments
**Severity:** Low  
**Labels:** build, enhancement

**Description:**
No explicit control over which kernel drivers are included.

**Recommendation:**
Add config fragments to ensure specific drivers (I2C, SPI, GPIO, CAN) are compiled.

---

### 15. L3: No CI Testing for All Boards
**Severity:** Low  
**Labels:** ci, enhancement

**Description:**
CI workflow only tests rpi5 board.

**Recommendation:**
Expand CI to test multiple board types.

---

### 16. L4: SSH Key Generation Not Documented
**Severity:** Low  
**Labels:** documentation, good first issue

**Description:**
Users don't know how to set up SSH keys.

**Recommendation:**
Document how to add SSH keys via BUILD_ENV or first-boot configuration.

---

### 17. L5: No Patch Naming Convention
**Severity:** Low  
**Labels:** documentation, enhancement

**Description:**
No documented patch naming convention.

**Recommendation:**
Document patch naming convention in CONTRIBUTING.md.

---

### 18. L6: No Entropy Check for Credential Generation
**Severity:** Low  
**Labels:** security, enhancement

**Description:**
First-boot password generation doesn't verify system has enough entropy.

**Recommendation:**
Add entropy check before credential generation.

---

### 19. L7: U-Boot Configuration Questionable for RPi5
**Severity:** Low  
**Labels:** bug, build

**Description:**
U-Boot configuration may not apply to RPi5 which uses RPi firmware, not U-Boot as primary bootloader.

**Recommendation:**
Review and fix U-Boot configuration for RPi5/CM5.

---

## Summary

| Severity | Count | Labels |
|----------|-------|--------|
| Critical | 4 | bug, security, stability, functionality |
| High | 3 | bug, security, functionality |
| Medium | 5 | bug, documentation, security, build |
| Low | 7 | documentation, build, enhancement, ci |

Total: 19 issues
