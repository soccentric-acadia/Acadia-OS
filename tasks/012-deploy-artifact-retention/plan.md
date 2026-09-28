# Task 012 (Acadia-OS leaf) — Deploy artifact retention

Parent task: [`tasks/012-deploy-artifact-retention/plan.md`](../../../tasks/012-deploy-artifact-retention/plan.md)

## Scope (this repository only)

> **Approved 2026-09-28** — implement as planned. Requirement: the Makefile
> changes carry maximum explanatory comments (variables, prune algorithm,
> invariants, failure semantics) so the retention logic is reviewable
> without the task record.
- `Makefile`: `DEPLOY_KEEP ?= 1` variable; prune step appended to
  `deploy-images` (after `checksums`), `deploy-sdk`, `deploy-esdk`.
  Prune removes `$(DEPLOY_DIR)/<type>/$(BOARD)_*` dirs beyond the newest
  `DEPLOY_KEEP`, never the dir just written, never other boards, never
  `deploy/swu/`.
- `doc/BUILD_DEPLOY.md`: retention paragraph (one copy per type by default).
- `CHANGELOG.md` entry.

## Affected interfaces

- Local build tooling only. No recipe, image, kernel, or packaging change.
  `deploy/<type>/<BOARD>_<TS>/` naming contract is preserved.
- Consumers verified compatible: `validation/tools/generate-manifest.sh`
  (newest-pick), `.github/workflows/build.yml` (single build per job).

## Local tests

- `make -n` dry-run of the three deploy targets.
- Live deploy against the existing build tree (`build/tmp/deploy/…` has
  artifacts) → confirm copy + checksums + prune to 1; confirm other-board
  dirs (none currently) and `deploy/swu/` untouched.
- `make manifest` after prune.

## Role in cross-repository validation

None required — no cross-repository contract is touched. Parent records the
result; validation suite is a consumer that remains compatible by design.