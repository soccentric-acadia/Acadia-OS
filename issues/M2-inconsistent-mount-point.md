# M2: Inconsistent Partition Mount Point Documentation

**Severity:** Medium  
**Category:** Documentation  
**Created:** 2026-06-08

## Problem

Partition mount point documentation is inconsistent - WKS file says `/home`, README says `/data`.

## Evidence

### Files
- `meta/meta-acadia/wic/sdimage-rpi5.wks` (line 24)
- `meta/meta-acadia/swupdate/README.md` (line 64)
- `README.md` (line 327)

### Issues
1. **sdimage-rpi5.wks line 24**: `part /home --source empty --ondisk mmcblk0 --fstype=ext4 --label home`

2. **swupdate/README.md line 64**: Describes p4 as `/data`:
   ```
   | p4 | `data` | ~238 GB (rest of card) | ext4 | `/data` | Persistent user / application data |
   ```

3. **README.md line 327**: Describes p4 as `/home` in the diagram:
   ```
   |  p4  /home      512 MB*  ext4    persistent home            |
   ```

4. **README.md line 308**: References "persistent `/home` partition" in features

## Impact

- Confusion about partition layout and mount point
- Users may expect data at `/data` but it's at `/home`
- Inconsistent documentation reduces trust in the project

## Recommendation

**Standardize on one mount point** and update all references:

### Option 1: Use /home (recommended - consistent with existing code)
- Keep p4 mounted at `/home`
- Update swupdate/README.md line 64 to show `/home`
- Update README.md to consistently refer to `/home`

### Option 2: Use /data (if persistent data is the primary use case)
- Change WKS file to mount at `/data`
- Update all documentation to use `/data`
- Add `/home` as a subdirectory if needed

## References

- `meta/meta-acadia/wic/sdimage-rpi5.wks:24`
- `meta/meta-acadia/swupdate/README.md:64`
- `README.md:327`
