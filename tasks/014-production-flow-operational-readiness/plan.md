# Task 014 — Acadia-OS scope

Parent plan: [Acadia Task 014](../../../../tasks/014-production-flow-operational-readiness/plan.md).

## Scope

Acadia-OS packages the exact Instrumentation, Configuration, and supporting production components and is responsible for the device boot/update/recovery boundary. Execute only the OS-owned items in the parent [Execution_plan.md](../../../../tasks/014-production-flow-operational-readiness/Execution_plan.md): P0-03, P0-05, P0-06, P0-14 through P1-18, P1-21, P2-23, and P0-26.

## Interfaces and expected work

- Pinned recipes and release manifests for Instrumentation and WebConfig.
- Board capability, identity, certificate/key storage, and persistent-data lifecycle.
- Boot chain, verified boot/rootfs decision, A/B slots, SWUpdate, rollback, factory reset, provenance, signing, SBOM/CVE, and HIL tooling.

## Local and cross-repository validation

Run existing image/package/reproducibility checks; build a clean pinned image; run signed-update, forced-rollback, recovery, reset, and provenance checks on each supported board. Validate the resulting image with Instrumentation, Configuration, HQ, HAL, Client, and Hardware ownership boundaries.
