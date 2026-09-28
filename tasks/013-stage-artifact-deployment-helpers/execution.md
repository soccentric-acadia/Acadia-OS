# Task 013 — Execution record

Parent task: [`tasks/013-stage-artifact-deployment-helpers/plan.md`](../../../tasks/013-stage-artifact-deployment-helpers/plan.md)

| Field | Value |
|---|---|
| Status | in progress |
| Plan approval | 2026-09-28 |
| Approved scope | Stage guarded image, SDK/eSDK, and SWU deployment helpers beside existing Acadia-OS artifacts. |

## Implementation checklist

- [x] Create this execution record before implementation.
- [x] Add the four helper-script templates under `scripts/`.
- [x] Stage a helper from each deploy target after artifact copying.
- [x] Update build/deployment documentation.
- [x] Add and run fixture-based helper tests.
- [x] Record validation evidence and resulting files.

## Implementation decisions

- WIC is authoritative for the SD-card partition table. No whole-device
  FAT32 format operation will be added.
- SDK/eSDK installers receive `-d /tool` through `sudo`.
- SWU transfer uses a preconfigured SSH identity and known host. The helper
  does not accept passwords, keys, or an option to disable host-key checks.

## Files changed

- `scripts/flash-image.sh`
- `scripts/install-sdk.sh`
- `scripts/install-esdk.sh`
- `scripts/install-swu.sh`
- `tests/test-deployment-helpers.sh`
- `Makefile`
- `doc/BUILD_DEPLOY.md`
- `CHANGELOG.md`
