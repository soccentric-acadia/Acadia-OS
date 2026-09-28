# Task 005 validation — `rt-test` standalone RT test application (Acadia-OS)

- **Date:** 2026-09-21
- **Status:** build + packaging verified 2026-09-28 — image
  `rpi5_20260928_104811` (rootfs-20260924142709, built 2026-09-24) contains
  `/usr/bin/instr-rt-test` (SRCREV pin `3d03ba6` ⊇ commit `3e885c2`);
  on-target RT/non-RT runs still pending hardware

## Evidence so far

- Recipe change reviewed: one explicit install line
  (`install -m 0755 ${B}/tools/instr-rt-test ${D}${bindir}/instr-rt-test`)
  following the same pattern as the daemon install loop directly above.
- No `SYSTEMD_SERVICE` change needed (plain one-shot binary, no unit by design).

## Pending

- ~~`make build rpi5` with the current pin → verify `/usr/bin/instr-rt-test`
  in the built image~~ **done 2026-09-28** (artifact verification, no rebuild
  needed — see parent `validation.md` update).
- On-target run as root on the RT image + paired non-RT run (owner:
  platform team) — see parent validation.md for the full checklist.

## Skipped checks (with reason)

- Image build in this session — the recipe pins a SRCREV; building now would
  produce an image without the tool and prove nothing about the change.