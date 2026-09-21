# Task 007 (Acadia-OS) — Ship the first-use-provisioning instrumentation build

Parent task: `tasks/007-first-use-provisioning/plan.md` (Acadia parent
repository). Status: draft — awaiting approval. Date: 2026-09-21.
Owner: Sandesh Ghimire.

## Scope (this repository only)

All implementation already lives in Acadia-Instrumentation. This repository
ships it: bump the pinned instrumentation revision, rebuild, and verify the
image carries the complete default file set that istate seeds into `/pst`
on first use.

## Affected interfaces and components

1. `meta/meta-acadia/recipes-instrumentation/instrumentation/instrumentation.bb`
   - `INSTR_SRCREV` → the landed task-007 instrumentation commit.
   - No recipe-logic changes: the recipe already installs the **whole**
     `system/defaults` tree to `${datadir}/instrumentation/defaults`
     (verified in task-003 inspection); istate simply ignored the
     non-`config.yaml` files until now.
2. No change: `acadia-pst-init`, `pst.mount`, `sdimage-rpi5.wks`, systemd
   units, sysusers/tmpfiles (task 003 artifacts are prerequisites and stay).

## Expected files

- `instrumentation.bb` (one SRCREV line) + changelog entry at commit time.

## Local tests / validation role

- Full `make build rpi5` green with the bumped pin.
- Built-rootfs inspection: `/usr/share/instrumentation/defaults/` contains
  all 14 shipped files (10 × config.yaml + catalog.yaml + fault-rules.yaml +
  devices.yaml + wg-peer.yaml).
- `make test-wiring` green.

## Cross-repository role

- Consumes the validated Acadia-Instrumentation commit (provider-first
  publication order); records the pin bump in execution.md so the image
  revision stays traceable to the reviewed implementation.