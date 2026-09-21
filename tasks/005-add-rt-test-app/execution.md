# Task 005 execution — Add `rt-test` standalone RT test application (Acadia-OS)

Parent task: `Acadia/tasks/005-add-rt-test-app/plan.md`
- **Approval date:** 2026-09-21
- **Approved scope:** one install line in `instrumentation.bb`; no systemd,
  no image-recipe change
- **Status:** recipe change implemented; image build pending SRCREV bump

## Implementation checklist

- [x] `instrumentation.bb` do_install: add the explicit install line for
      `${B}/tools/instr-rt-test → ${bindir}/instr-rt-test`
- [ ] `make build rpi5` green with the new line — **pending**: blocked on the
      Acadia-Instrumentation commit, because the recipe pins
      `INSTR_SRCREV` (`b82237ad…`); the image build only picks up
      `instr-rt-test` after the provider revision exists upstream and the
      pin is bumped. Steps at release time:
      1. commit Acadia-Instrumentation (task 005 files),
      2. bump `INSTR_SRCREV` in `instrumentation.bb` to that commit,
      3. `make build rpi5`, verify `/usr/bin/instr-rt-test` in the image.

## Files changed

- `meta/meta-acadia/recipes-instrumentation/instrumentation/instrumentation.bb`
  — note: `meta/` is a nested clone of the meta-acadia repository (kas-fetched,
  gitignored from Acadia-OS); the edit is tracked by the meta-acadia git repo,
  not by the Acadia-OS repo itself.

## Interface / schema / dependency changes

- Image content only: adds `/usr/bin/instr-rt-test`. No unit, no service
  user, no boot-path change (the app is a plain one-shot binary run manually).

## Deviations from the approved plan

- None.