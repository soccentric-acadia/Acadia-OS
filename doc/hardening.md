# Acadia Production Image Hardening (Task 53)

This document records the production-image hardening profile and how it is
checked. The base image (`acadia-image.bb`) is a production build for the
Raspberry Pi 5; debug/broad tooling must be gated and exposure must be auditable.

## Hardening posture

- **SSH**: `openssh` ships with `acadia-hardening.conf` →
  `PasswordAuthentication no`, `PermitRootLogin no` (SSH-key access only).
- **Operator account**: locked password, SSH-key only.
- **webconfigd**: runs non-root, hardened systemd unit (task 40).

## Exposure checks (enforced by `scripts/harden-image.sh` / `make lint-hardening`)

The gate scans the image recipe + packaging for the classic production gaps and
fails if any is present unconditionally:

1. **Empty/root password** — an image that enables `empty-root-password` or
   `debug-tweaks` (which permits root login without a password) must not be a
   production default.
2. **Open ports / default credentials** — no hardcoded passwords or
   world-open services beyond the documented UI/SSH.
3. **Broad tooling** — the debug/dev packages (`tools-debug`, `gdbserver`,
   `openocd`, `valgrind`) are development aids; they must be gated behind an
   explicit `IMAGE_FEATURE`/variable so a production build can exclude them, not
   unconditionally present.
4. **Service privileges** — services run non-root with restricted capabilities
   (checked for the shipped units).

## Gate

```bash
make lint-hardening
```

Runs `scripts/harden-image-check.sh` which scans `acadia-image.bb`, the
`packagegroup-*` recipes, and the sshd/serice units for the gaps above. CI runs
it in the static-validation job.
