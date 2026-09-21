# Task 003 (Acadia-OS) — Add persistent 1 GB `/pst` partition

Parent task: `tasks/003-add-pst-partition/plan.md` (Acadia parent repository).
Status: draft — awaiting approval. Date: 2026-09-21. Owner: Sandesh Ghimire.

## Scope (this repository only)

All implementation lives in the `meta/meta-acadia` layer (nested clone).

## Affected interfaces and components

1. **WIC layout** — `meta/meta-acadia/wic/sdimage-rpi5.wks`
   - Add p4: `part --source empty --ondisk mmcblk0 --fstype=ext4 --label pst
     --align 4096 --fixed-size 1024M` (no mountpoint → no fstab entry).
   - `/home` becomes p5 (still last → `rpi5-home-init` growth logic intact).
   - Update the header comment block documenting the layout.
2. **New recipe** `meta/meta-acadia/recipes-core/acadia-pst-init/`
   - `files/pst.mount` — systemd mount unit: `What=LABEL=pst`,
     `Where=/pst`, `Type=ext4`, `After=local-fs.target`,
     `Before=multi-user.target`, `WantedBy=local-fs.target`,
     `ConditionPathExists=/dev/disk/by-label/pst` (migration-safe skip on
     devices with the old 4-partition layout).
   - `files/acadia-pst-init.service` — oneshot, `After=local-fs.target`,
     `After=systemd-sysusers.service`, `RequiresMountsFor=/pst`.
   - `files/acadia-pst-init.sh` — chown `instr-istate:instr` 0750 on `/pst`
     when the sysusers-created users exist, else `root:root` 0755;
     idempotent via `/pst/.pst-initialised`.
   - `files/instr-istate.service.d/pst-order.conf` — drop-in with
     `RequiresMountsFor=/pst` so the sole `/pst` owner never starts with the
     store unmounted (skipped mount units do not fail dependents).
   - `acadia-pst-init.bb` — systemd recipe modelled on `rpi5-home-init.bb`.
3. **Image** — `recipes-core/images/acadia-image.bb`: install
   `acadia-pst-init` for `raspberrypi5` and `raspberrypi-cm5-io-board`.
4. **Documentation** — `meta/meta-acadia/swupdate/README.md` (partition
   diagram, `/pst` persistence notes), wks header.
5. **Changelog** — `CHANGELOG.md` entry for task 003.

## Expected files

```text
meta/meta-acadia/wic/sdimage-rpi5.wks                       (modified)
meta/meta-acadia/recipes-core/acadia-pst-init/acadia-pst-init.bb            (new)
meta/meta-acadia/recipes-core/acadia-pst-init/files/pst.mount               (new)
meta/meta-acadia/recipes-core/acadia-pst-init/files/acadia-pst-init.service (new)
meta/meta-acadia/recipes-core/acadia-pst-init/files/acadia-pst-init.sh      (new)
meta/meta-acadia/recipes-core/acadia-pst-init/files/instr-istate.service.d/pst-order.conf (new)
meta/meta-acadia/recipes-core/images/acadia-image.bb        (modified)
meta/meta-acadia/swupdate/README.md                         (modified)
CHANGELOG.md                                                (appended)
tests (bats)                                                (new/extended)
```

## Local tests

- Extend `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/tests/test_wic_layout.bats`:
  exactly one `pst` partition, `--fixed-size 1024M`, label `pst`, declared
  before the `/home` partition, `/home` still the last partition.
- New `recipes-core/acadia-pst-init/tests/test_pst_init.bats`: mount unit
  uses `LABEL=pst` + `ConditionPathExists`; init service carries
  `RequiresMountsFor=/pst`; drop-in present.
- `make test-wiring`; existing `rpi5-swupdate-config` bats suites stay green.

## Role in cross-repository validation

- Provider of the `/pst` mount contract consumed by Acadia-Instrumentation:
  mounted before istate starts, owned by `instr-istate:instr`, never written
  by SWUpdate.
- Build rpi5 image; verify artifact-level guarantees (partition table,
  fstab, units present in both the `.wic` rootfs and the OTA-packaged
  `.rootfs.ext4`) per the parent plan's validation strategy.
- On-target steps (fresh flash, OTA round-trip, old-layout OTA) are
  documented in the parent plan and recorded here when hardware access
  allows.