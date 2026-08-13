# Acadia-OS

**Remote:** `git@github.com:soccentric-acadia/Acadia-OS.git`
**Parent project:** [Acadia](../Acadia.md) (target hardware: **Raspberry Pi 5 / CM4/CM5** (BCM2712 + RP1) app processor + **Pico W** (RP2040) real-time co-processor.)
**Leaf type:** `<Project>-OS`
**Status:** REAL — reference/baseline platform

Yocto-based embedded Linux OS for the **Raspberry Pi** platform. Built with
`kas` + Docker against the `meta-raspberrypi` layer set, with A/B OTA updates
via `swupdate`. This is the **reference** for the fleet: other platforms
(Zion/Joshua/Pinnacle/Sequoia) are documented as ports of this repo.

**Board:** default `rpi5`. Platform customization lives in
`meta/meta-acadia` (committed locally); upstream layers (`poky`,
`meta-openembedded`, `meta-raspberrypi`, `meta-swupdate`) are checked out by
kas into a **gitignored** `layers/` directory and must never be hand-edited.

**Targets:** `make build`, `make image`, `make shell [board]`, `make swu`,
`make sdk`/`esdk`, `make flash`, `make deploy-*`, `make clean`/`clean-all`.

**Boot flow (RPi 5):**
```
SD/eMMC → RPi firmware (config.txt) → U-Boot → kernel_2712.img
        → Linux → systemd → Acadia-HAL, Acadia services
```

**A/B OTA layout:** `boot` (FAT32), `rootfs-a`, `rootfs-b` (ext4, switched by
swupdate), `data` (`/home`, persistent). See
`meta/meta-acadia/wic/sdimage-rpi5.wks`.

**Local layer:** `meta/meta-acadia` is committed in-repo (see `.gitignore`).

---
Part of the `Acadia` project in the `project-managers` fleet. See
`docs/project-managers.md` for the full 9-project / 8-leaf hierarchy and shared
conventions.
