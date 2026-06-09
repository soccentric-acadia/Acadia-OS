# L8: No .gitignore for meta-acadia

**Severity:** Low  
**Category:** Development Process  
**Created:** 2026-06-08

## Problem

The meta-acadia layer has no .gitignore file, potentially committing build artifacts.

## Evidence

### Files
- `meta/meta-acadia/` (no .gitignore)

### Issue
- No `.gitignore` file in meta-acadia layer
- Build artifacts from Yocto builds may be accidentally committed
- Temporary files, logs, and compiled artifacts could leak into repository

## Impact

- Build artifacts may be committed to repository
- Repository size could grow unnecessarily
- Sensitive files may be accidentally committed

## Recommendation

Add `.gitignore` to meta-acadia layer:

```
# Yocto/BitBake generated files
*.pyc
__pycache__/
bitbake.lock
cache/
tmp/
build/

# Logs
*.log

# Temp files
*.tmp
*.swp
*~

# IDE files
.idea/
.vscode/
*.sublime-project
*.sublime-workspace

# Documentation generated files
*.html
*.pdf

# Distfiles (usually in separate DL_DIR but sometimes checked in)
# *.tar.gz
# *.zip

# Generated bbappends (if any)
# recipes-*/*/*.bbappend

# meta- prefix (common convention)
# meta-*/
```

Or a more minimal version:
```
# Build artifacts
build/
tmp/
cache/

# Logs and temp files
*.log
*.tmp
*.swp
```

## References

- N/A - this is a new file to create
