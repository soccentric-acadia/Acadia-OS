# C3: Acadia-Client Excluded from Image

**Severity:** Critical  
**Category:** Functionality  
**Created:** 2026-06-08

## Problem

The primary application daemon (acadia-client) is not included in the OS image, despite being built as part of the layer.

## Evidence

### Files
- `meta/meta-acadia/recipes-core/images/core-image-full-cmdline.bbappend` (lines 98-100)
- `meta/meta-acadia/recipes-core/images/acadia-image.bb` (lines 42-44)
- `meta/meta-acadia/recipes-connectivity/acadia-client/acadia-client_git.bb`

### Issues
1. **core-image-full-cmdline.bbappend line 99**: Has comment `# NOTE: acadia-client excluded until upstream repo is available`

2. **core-image-full-cmdline.bbappend line 100**: Only includes `acadia-hal acadia-services` - NOT `acadia-client`

3. **acadia-image.bb line 44**: Same exclusion comment and missing acadia-client from IMAGE_INSTALL

4. **acadia-client_git.bb line 16**: Uses hardcoded `SRCREV = "71ee04ec3f9bb06cce989baae6de6f37148fb50d"` - this is not a proper upstream release

5. **acadia-data-init.service and var-lib-acadia.mount** exist but are not wired up in the image

## Impact

The primary application daemon is missing from the build. Users will have acadia-hal and acadia-services but not the client daemon that connects to the Acadia IV&V server.

## Recommendation

1. **Remove the acadia-client exclusion comment** and add to `IMAGE_INSTALL` in both:
   - `core-image-full-cmdline.bbappend`
   - `acadia-image.bb`

2. **Update acadia-client_git.bb** to use proper pinned SRCREV when upstream repo is available:
   ```bitbake
   # TODO: replace with the real commit SHA once the upstream repo exists:
   # SRCREV = "<40-char-sha>"
   ```

3. **Ensure proper systemd dependency ordering** between `acadia-client` and `swupdate-bootcheck`

4. **Include acadia-data-init** for persistent storage:
   ```bitbake
   IMAGE_INSTALL:append = " acadia-data-init"
   ```

## References

- `meta/meta-acadia/recipes-core/images/core-image-full-cmdline.bbappend:99-100`
- `meta/meta-acadia/recipes-core/images/acadia-image.bb:42-44`
- `meta/meta-acadia/recipes-connectivity/acadia-client/acadia-client_git.bb:16`
