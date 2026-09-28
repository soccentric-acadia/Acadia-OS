# Task 013 — Stage deployment helpers beside release artifacts

Parent task: [`tasks/013-stage-artifact-deployment-helpers/plan.md`](../../../tasks/013-stage-artifact-deployment-helpers/plan.md)

## Scope

- Add reviewed Bash helper templates under `scripts/` for:
  - flashing the colocated WIC image to an explicitly named SD-card block
    device;
  - installing the colocated SDK or eSDK installer into `/tool` with `sudo`;
  - copying the colocated SWU to `[user@]host` through SSH and invoking
    `sudo swupdate -i` remotely.
- Stage the relevant executable helper in each successful `deploy-images`,
  `deploy-sdk`, `deploy-esdk`, and `deploy-swu` output directory.
- Document usage, host prerequisites, the WIC-created FAT32 boot partition,
  and destructive-operation/SSH safeguards in `doc/BUILD_DEPLOY.md`.

## Affected interfaces

- Additive files in the existing `deploy/images/`, `deploy/sdk/`,
  `deploy/esdk/`, and `deploy/swu/` timestamped directories.
- No change to artifact filenames, WIC layout, SDK/eSDK payload, SWU format,
  update signatures, or Make target arguments.
- The image helper must write the WIC image rather than format the complete
  device as FAT32; the WIC owns its multi-partition layout.

## Expected components

- `Makefile` deploy targets
- `scripts/flash-image.sh`
- `scripts/install-sdk.sh`
- `scripts/install-esdk.sh`
- `scripts/install-swu.sh`
- `doc/BUILD_DEPLOY.md`
- focused helper-script tests, if the existing repository test organization
  supports them
- `CHANGELOG.md` and task execution/validation records after approval

## Local validation

- Bash syntax and, when available, ShellCheck for each helper.
- Make dry-runs of all four deploy targets.
- Fixture tests with command doubles for block-device validation, installer
  selection, privileged command construction, SSH/SCP command ordering, and
  failure propagation.
- Hardware validation with a disposable card and signed SWU on a supported
  Raspberry Pi.

## Cross-repository validation role

The produced image must boot the already integrated HAL, Client,
Instrumentation, and Configuration components. The signed SWU path must
preserve the target's existing SWUpdate/A-B/rollback behavior. No leaf API or
package format changes are planned.

