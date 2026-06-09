# L5: No Patch Naming Convention

**Severity:** Low  
**Category:** Development Process  
**Created:** 2026-06-08

## Problem

No documented patch naming convention in the project.

## Evidence

### Files
- `meta/meta-acadia/recipes-connectivity/acadia-client/files/0001-fix-grpc-cpp-plugin-cross-compile.patch`

### Issue
- Patch file exists: `0001-fix-grpc-cpp-plugin-cross-compile.patch`
- No documented naming convention
- Other patches may follow different naming

## Impact

- Inconsistent patch file naming
- Difficult to understand patch purpose from filename
- No guidance for contributors

## Recommendation

Document patch naming convention in `CONTRIBUTING.md` or `meta-acadia/README.md`:

```markdown
## Patch Files

Patches should follow this naming convention:

```
##-description.patch
```

Where `` is:
- `0001`, `0002`, etc. for the first few patches
- A descriptive name if there are many patches

Examples:
- `0001-fix-grpc-cpp-plugin-cross-compile.patch`
- `0001-Add-support-for-custom-hardware.patch`

Always include `Upstream-Status` in patch header:
- `Upstream-Status: Backport` - backported from upstream
- `Upstream-Status: Submitted` - submitted to upstream
- `Upstream-Status: Inappropriate` - not for upstream (e.g., Yocto workaround)
```

## References

- `meta/meta-acadia/recipes-connectivity/acadia-client/files/0001-fix-grpc-cpp-plugin-cross-compile.patch`
