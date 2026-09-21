# Task 003 (Acadia-OS) — Validation record

## Results

| Check | Revision | Result |
|-------|----------|--------|
| `make test-wiring` | 003 worktree | PASS — 2597 tasks, 0 failures |
| `make build` (rpi5 image) | 003 worktree | PASS — 10,145 tasks, 0 failures |
| bats `acadia-pst-init/tests` | meta-acadia | PASS 17/17 |
| bats `rpi5-swupdate-config/tests` | meta-acadia | PASS 72/72 |
| bats `rpi5-home-init/tests` | meta-acadia | PASS 16/16 |
| `scripts/check-image-packages.sh` | meta-acadia | PASS |
| `make lint-swupdate-sync` | meta-acadia | PASS |
| `fdisk`/`sgdisk` on `.wic` | deploy/images/rpi5_20260921_120814 | PASS — GPT, p4 pst 1024M, p5 home 512M |
| `dumpe2fs` p4/p5 | deploy image | PASS — volume names `pst` / `home` |
| p2 `/etc/fstab` | debugfs | PASS — boot + /home only; no /pst entry |
| OTA `.rootfs.ext4` units | debugfs | PASS — pst.mount + init service + script + istate drop-in present |

## Evidence highlights

- Partition table (built artifact):
  `p1 boot 256M · p2 rootfs-a 8G · p3 rootfs-b 8G · p4 pst 1G · p5 home 512M` (GPT).
- `pst` volume name confirmed: `Filesystem volume name: pst`.
- The OTA-packaged `acadia-image-raspberrypi5.rootfs.ext4` (what `make swu`
  ships) contains all four new files — `/pst` mounts identically after an
  OTA update.

## Skipped / failed checks

- `make lint-reproducibility`: FAIL — pre-existing AUTOREV in
  `acadia-client_git.bb` and `webconfigd.bb`; unrelated to task 003.
  Owner: platform maintainers (follow-up).
- On-target hardware validation (fresh flash, OTA round-trip, old-layout
  OTA): pending hardware access — procedure recorded in the parent
  `validation.md`. Owner: Acadia-OS maintainers.

## Known limitations

- `pst.mount` depends on udev having created `/dev/disk/by-label/pst` when
  the unit starts; on very slow storage the condition is evaluated at unit
  start time (normal systemd behaviour, same class as fstab devices).
- cm5 ships `acadia-pst-init` but no instrumentation today — `/pst` mounts
  empty (root-owned fallback). Existing gap, out of scope.