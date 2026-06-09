# L9: Documentation References Wrong Path

**Severity:** Low  
**Category:** Documentation  
**Created:** 2026-06-08

## Problem

SWUpdate README references wrong layer path (`meta/meta-custom/` instead of `meta/meta-acadia/`).

## Evidence

### Files
- `meta/meta-acadia/swupdate/README.md` (lines 114-131)

### Issue
README at lines 114-131 references:
```
meta/meta-custom/
├── swupdate/                          ← .swu packaging sources (host-side)
│   ├── sw-description
│   ├── pre-install.sh
│   └── post-install.sh
│
└── recipes-swupdate/
    └── rpi5-swupdate-config/
        └── files/
```

But the actual path is `meta/meta-acadia/` not `meta/meta-custom/`.

## Impact

- Users may look for files in wrong location
- Documentation is confusing
- Inconsistent with actual project structure

## Recommendation

Update README to reference correct path `meta/meta-acadia/`:

```markdown
meta/meta-acadia/
├── swupdate/                          ← .swu packaging sources (host-side)
│   ├── sw-description                 Template; @@VERSION@@ substituted by make swu
│   ├── pre-install.sh                 Copied verbatim into every .swu
│   └── post-install.sh                Copied verbatim into every .swu
│
└── recipes-swupdate/
    └── rpi5-swupdate-config/
        ├── rpi5-swupdate-config.bb    BitBake recipe
        └── files/
            ├── swupdate.cfg           libconfig runtime config
            ├── pre-install.sh         Installed to /usr/lib/swupdate/
            ├── post-install.sh        Installed to /usr/lib/swupdate/
            ├── swupdate-bootcheck.sh  Boot-slot logger
            ├── swupdate-bootcheck.service
            └── swupdate-webui.conf    systemd drop-in for swupdate.service
```

## References

- `meta/meta-acadia/swupdate/README.md:114-131`
