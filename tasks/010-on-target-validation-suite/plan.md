# Task 010 — On-target validation suite (leaf record: Acadia-OS)

Parent task: `tasks/010-on-target-validation-suite/plan.md` (Acadia root).

| Field | Value |
|---|---|
| Class | validation-only (no source changes in this repo) |
| Track | Production |
| Date | 2026-09-26 |

## Scope in this repository

The Acadia root gains `validation/` — a Python suite executed from an x86 host
that validates the artifacts this OS layer installs on the flashed Raspberry Pi
image, against the layout shipped by
`meta-acadia/recipes-instrumentation/instrumentation/instrumentation.bb`:

- `/usr/bin/instr-<daemon>`, `/usr/bin/{istate_ctrl,alarm_ctrl,monitor_ctrl,
  hardware_ctrl,fault_ctrl,log_ctrl,telemetry_ctrl,network_ctrl,ota_ctrl,backup_ctrl}`,
  `/usr/bin/instr-istate-watchdog`, `/usr/bin/instr-rt-test`;
- `/lib/systemd/system/instr-*.service` (+ `webconfigd.service.d/instr-socket.conf`),
  enablement expectations including T-P00c (instr-ota shipped, not enabled);
- `/etc/sysusers.d/instrumentation.conf`, `/usr/lib/tmpfiles.d/instrumentation.conf`,
  `/etc/udev/rules.d/70-instrumentation.rules`,
  `/usr/share/polkit-1/rules.d/60-instrumentation.rules`;
- `/etc/instrumentation/{devices,capabilities,resource-profile,fault-rules}.yaml`
  (per-`INSTR_BOARD`), `/usr/share/instrumentation/{catalog,defaults,schemas,proto}`;
- COMPATIBLE_MACHINE: raspberrypi4-64, raspberrypi5, raspberrypi-cm5-io-board —
  the suite's board expectation is configurable (`target.board`).

## Affected interfaces

None changed. The suite verifies the deployed image.

## Local tests / role in cross-repository validation

None added (validation-only). A full `--host <pi>` run is direct HIL evidence
for the image (integration-production §6).