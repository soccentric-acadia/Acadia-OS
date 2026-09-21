# Task 003 (Acadia-OS) — Execution record

- **Approval date:** 2026-09-21 (parent plan approved; user replied "ok").
- **Role:** affected — all implementation in the meta-acadia layer.

## Checklist

- [x] WIC layout: `pst` p4 (1 GB ext4, label `pst`, no mountpoint), `/home` → p5, GPT table, header comments updated
- [x] `acadia-pst-init` recipe + units + script + istate drop-in + bats tests
- [x] `acadia-image.bb`: `acadia-pst-init` installed for raspberrypi5 and raspberrypi-cm5-io-board
- [x] `swupdate/README.md` partition diagram and OTA-persistence notes
- [x] `test_wic_layout.bats` extended (pst partition, no mountpoint, ordering, mkfs assertion)
- [x] CHANGELOG entry

## Interface / configuration changes

- Partition layout: p4 `pst` (1024 MB, ext4, label `pst`), p5 `/home` (grows
  to fill card on first boot). MBR → GPT (rationale in parent validation.md).
- New systemd units in the rootfs: `pst.mount` (WantedBy=local-fs.target,
  `ConditionPathExists=/dev/disk/by-label/pst`), `acadia-pst-init.service`
  (RequiresMountsFor=/pst, After=systemd-sysusers.service), and
  `instr-istate.service.d/pst-order.conf` (After=acadia-pst-init.service).
- `/pst` rootfs mountpoint skeleton packaged in `acadia-pst-init`.

## Commands run

`make test-wiring` (PASS), `make build` (PASS, 10,145 tasks), bats suites
(17/17, 72/72, 16/16), `scripts/check-image-packages.sh` (PASS),
`make lint-swupdate-sync` (PASS), `fdisk`/`sgdisk`/`debugfs`/`dumpe2fs`
artifact inspection (PASS). `make lint-reproducibility` FAILs on pre-existing
AUTOREV uses in acadia-client/webconfig recipes (unrelated to this task).

## Deviations from the leaf plan

1. GPT table switch (approved scope consequence — documented above).
2. `/home` mkfs fix (pre-existing unformatted-partition defect).
3. Per-spoke dirs in init script (ReadWritePaths contract).
4. Drop-in reduced to `After=acadia-pst-init.service`.

No breaking interface changes; SWUpdate scripts and instrumentation code
untouched.