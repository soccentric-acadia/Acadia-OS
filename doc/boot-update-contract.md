# Boot and Update Contract (Task 52)

Versioned contract for partition labels, boot arguments, tryboot authority,
filenames, and rollback ownership. This is the single authority the OS scripts,
SWUpdate flow, and rollback chain follow.

## A/B partition layout (sdimage-rpi5.wks)

| Partition | Label | Mount | Size | Purpose |
|---|---|---|---|---|
| p1 | boot | /boot (vfat) | 256 MB | kernel, DTBs, config.txt, cmdline.txt |
| p2 | rootfs-a | / | 8192 MB | active rootfs slot (populated at build) |
| p3 | rootfs-b | — | 8192 MB | standby slot (written by SWUpdate) |
| p4 | home | /home | 512 MB→grows | persists across OTA |

## Boot filenames (fixed, versioned)

| File | Board(s) |
|---|---|
| `kernel_2712.img` | rpi5, cm5 |
| `bcm2712-rpi-5-b.dtb` | rpi5, cm5 |
| `cmdline.txt` | all (root=PARTUUID updated by post-install) |
| `config.txt` | all |

## Boot arguments / root

`cmdline.txt` carries `root=PARTUUID=<active>`; `post-install.sh` switches it to
the newly written slot's PARTUUID atomically (task 46).

## Bootloader & tryboot authority

- **RPi5/CM5** use RPi firmware tryboot: `boot_state` (`slot`, `tries_remaining=3`,
  `confirmed=false`) drives automatic rollback after N failed boots.
- **U-Boot boards** (CM1/CM3) use `upgrade_available=1`, `bootcount`,
  `bootlimit=3` env + `altbootcmd` to revert slots.
- **Rollback ownership**: the bootloader (tryboot/U-Boot) owns slot selection;
  `swupdate-bootcheck` + `boot-watchdog` confirm a healthy boot and clear the
  rollback. `bootcount-reset.service` clears `upgrade_available` on a healthy
  boot.

## OTA ownership

- SWUpdate owns writing the inactive slot; the bundled flow is only defined for
  `rpi5`/`cm5` (the boards selecting `sdimage-rpi5.wks` — tasks 48/49).
- Health check (task 47) covers HAL, webconfigd, networking, storage with
  bounded readiness before confirming the update.

## Gate

`make verify-swu` verifies bundle signatures; `swupdate-bootcheck.sh` +
`boot-watchdog` implement this contract on a booted image (target-required
tests: `test_rollback_target.bats`, `test_atomic_boot_files.bats`,
`test_wic_layout.bats`).
