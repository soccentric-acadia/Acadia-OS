# Task 014 — Acadia-OS execution record

- **Approval date:** 2026-09-28
- **Approved scope:** Parent Task 014 Phase 0, P0-03 and OS participation in P0-04.

## Checklist

- [x] P0-03 Repair and pin the OS release build path.
- [x] P0-04 Consume the supported production capability matrix.
- [x] P0-05 Establish one device identity lifecycle.

## Implementation record

### P0-03 — 2026-09-28

Implemented only the OS release-build scope:

- Added `release-sources.lock`, an auditable lock for the KAS version, six
  kas layer commits, Instrumentation, Configuration, HAL, Client, toml++,
  and Raspberry Pi Linux revisions.
- Added `scripts/check-release-sources.sh` and the
  `lint-release-sources` Make target. The gate rejects malformed lock input,
  non-40-character source revisions, `AUTOREV`, drift between the lock and
  kas/recipe pins, and regressions of the `RPI_EXTRA_CONFIG` and polkit
  packaging fixes.
- Added `scripts/tests/test_release_sources.bats` for the new gate and
  included the gate in `make lint`.

The existing pinned configuration already contained the concrete release
repairs: a syntactically valid multiline `RPI_EXTRA_CONFIG`, disabled
systemd-polkit integration (avoiding its premature `polkitd` chown), and
explicit polkit rule-directory packaging in WebConfig and Instrumentation.
This work records and continuously verifies those repairs; it does not alter
another repository's pinned `meta-acadia` source.

Validation executed:

| Command | Result |
| --- | --- |
| `bash scripts/check-release-sources.sh` | Passed: all locked source and release-blocker checks passed. |
| `bats scripts/tests/test_release_sources.bats` | Passed: 1/1. |
| `make lint` | Passed: SWUpdate sync, Makefile/YAML parsing, no `AUTOREV`, release-lock gate, and all image-package provider checks. |
| `make validate BOARD=rpi5` | Passed: all board configurations validated and rpi5 BitBake metadata parsed in kas 4.5. |
| `make test-wiring BOARD=rpi5` | Passed: clean-state rebuild of WebConfig, Instrumentation, HAL, and Client recipes in the KAS container. |
| `make build BOARD=rpi5` | Passed: rpi5 image build completed (10,671 tasks successful; all from valid sstate) and deployed a WIC/BMAP, SPDX SBOM, and SHA256 manifest to `deploy/images/rpi5_20260928_155009/`. |
| `make verify DEPLOY_DIR=deploy/images/rpi5_20260928_155009` | Passed: every deployed WIC, BMAP, SBOM, and flash helper matched `SHA256SUMS`; the built image manifest lists `instrumentation` at `3d03ba6`, `webconfigd` at `1063cace`, and `polkit`. |

Remaining P0-03 limitations:

- The successful image build reused the validated local sstate cache; a
  separate cold-cache/clean-checkout build is still required for independent
  reproducibility evidence.
- The pinned Configuration revision's Cargo build downloads its lockfile-pinned
  crates during its recipe build. Vendoring those crates belongs to the
  separately pinned `meta-acadia`/Configuration release work and was not
  changed under this OS-only scope.

### P0-04 — 2026-09-28

- Added `scripts/check-production-capability.sh`, which rejects every
  production `BOARD` except `rpi5` and `cm5`, requires the matching KAS
  machine, and requires Hardware matrix `1.0.0` with board revision
  `rpi5-cm5-bom-rev-c`.
- Added the matrix/version metadata to `kas/boards/rpi5.yaml` and
  `kas/boards/cm5.yaml`, and made `make build` fail closed through the new
  gate before invoking kas.
- Added `scripts/tests/test_production_capability.bats`, including the
  unsupported-`rpi4` negative case.

Validation executed:

| Command | Result |
| --- | --- |
| `bash scripts/check-production-capability.sh rpi5 kas/boards/rpi5.yaml` | Passed. |
| `bash scripts/check-production-capability.sh cm5 kas/boards/cm5.yaml` | Passed. |
| `bash scripts/check-production-capability.sh rpi4 kas/boards/rpi5.yaml` | Rejected as required. |
| `bats scripts/tests/test_production_capability.bats` | Passed: 2/2. |

### P0-05 — 2026-09-28

- Made the immutable factory identity record the canonical input to the
  persistent device ID; device-tree serial is used only before provisioning.
- The generated ID is stored atomically under `/pst/acadia`, survives OTA and
  full reset, and cannot be replaced by later serial input.
