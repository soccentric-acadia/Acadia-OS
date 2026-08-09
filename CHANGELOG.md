# Changelog

## [Unreleased]

### Added — project documentation

- **`CLAUDE.md`** and **`REPO_MAP.md`** — project documentation matching the
  fleet-wide convention.

### Notes

- Acadia-OS is the **reference/baseline** platform for the SiliconCentric
  fleet. It is the most fully built-out OS repo (146 files): complete
  `meta/meta-acadia` Yocto layer, 20 per-domain image variants, A/B OTA via
  swupdate with full rollback (boot-watchdog, bootcount-reset,
  swupdate-bootcheck), `rpi5-home-init`, connectivity, HAL, and a suite of
  Bats tests. Other platforms port from this template.
