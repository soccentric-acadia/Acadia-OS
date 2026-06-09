# H1: Non-Reproducible Builds

**Severity:** High  
**Category:** Build / Reproducibility  
**Created:** 2026-06-08

## Problem

Builds are not reproducible - external layer repos use `HEAD` or `AUTOREV` which always fetches the latest code.

## Evidence

### Files
- `kas/repos/poky.yaml`
- `kas/repos/meta-openembedded.yaml`
- `kas/repos/meta-swupdate.yaml`
- `kas/repos/meta-acadia.yaml`
- `meta/meta-acadia/recipes-bsp/acadia-hal/acadia-hal_git.bb`

### Issues
1. **poky.yaml lines 8-11**: 
   ```yaml
   commit: HEAD
   # TODO: pin to a specific commit for reproducible builds.
   ```

2. **meta-openembedded.yaml lines 8-9**: Same `commit: HEAD` with TODO comment

3. **meta-swupdate.yaml lines 8-9**: Same `commit: HEAD` with TODO comment

4. **meta-acadia.yaml line 8**: `# TODO: pin to a specific commit`

5. **acadia-hal_git.bb line 7**: `SRCREV = "${AUTOREV}"` - always fetches latest HEAD from git

## Impact

- Builds are not reproducible - different builds may use different code
- Debugging field issues is difficult (different hardware may have different build sources)
- sstate cache coherence is broken
- Cannot reliably rebuild a specific version months later

## Recommendation

1. **Pin all external layer repos** to specific commit SHAs in:
   - `kas/repos/poky.yaml`
   - `kas/repos/meta-openembedded.yaml`
   - `kas/repos/meta-swupdate.yaml`
   - `kas/repos/meta-acadia.yaml`

2. **Create a script** to help pin layers:
   ```bash
   # scripts/pin-layers.sh
   # Fetch current commit SHA for each repo and update yaml files
   ```

3. **For acadia-hal_git.bb**, replace `SRCREV = "${AUTOREV}"` with pinned SHA:
   ```bitbake
   # TODO: replace with the real commit SHA once the upstream repo exists:
   SRCREV = "71ee04ec3f9bb06cce989baae6de6f37148fb50d"
   ```

4. **Add SOURCE_DATE_EPOCH** in `kas/common.yaml` `local_conf_header` for reproducible builds

## References

- `kas/repos/poky.yaml:8-11`
- `kas/repos/meta-openembedded.yaml:8-9`
- `kas/repos/meta-swupdate.yaml:8-9`
- `kas/repos/meta-acadia.yaml:8`
- `meta/meta-acadia/recipes-bsp/acadia-hal/acadia-hal_git.bb:7`
