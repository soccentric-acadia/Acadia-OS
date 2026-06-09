# L3: No CI Testing for All Boards

**Severity:** Low  
**Category:** CI/CD  
**Created:** 2026-06-08

## Problem

CI workflow only tests rpi5 board - other 16 board configs are not automatically validated.

## Evidence

### Files
- `.github/workflows/build.yml` (line 29)

### Issue
- CI workflow only tests `rpi5` board (line 29: `matrix: board: [rpi5]`)
- Other 16 board configs are not automatically validated
- Matrix only includes one board type

## Impact

- Other board types are not tested automatically
- regressions in other board configurations may go undetected
- Manual testing required for each board type

## Recommendation

Expand CI to test multiple board types:

```yaml
# .github/workflows/build.yml
strategy:
  fail-fast: false
  matrix:
    board: [rpi5, rpi4-64, rpi3-64, cm5]
```

Or test a representative subset:
```yaml
matrix:
  board: [rpi5, rpi4-64, rpi3-64, rpi0-2w-64]
```

## References

- `.github/workflows/build.yml:29`
