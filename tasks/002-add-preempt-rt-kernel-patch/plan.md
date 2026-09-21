# Task 002 (leaf) — Add PREEMPT_RT patch to the Linux kernel — Acadia-OS

Parent task: `Acadia/tasks/002-add-preempt-rt-kernel-patch/plan.md`
- **Task ID:** 002
- **Date:** 2026-09-21
- **Status:** approved 2026-09-21 (aarch64-only scope, D1 resolved) — build-side complete; on-target pending
- **Class:** affected (sole implementation repository)

## Scope in this repository

Convert the Acadia kernel (`linux-raspberrypi`, pinned to 6.6.78 on `rpi-6.6.y`
via the existing meta-acadia bbappend) into a PREEMPT_RT kernel by applying the
upstream `patch-6.6.78-rt51` patch and enabling `CONFIG_PREEMPT_RT=y`. The
pinned SRCREV does not move.

## Expected files / components

1. `meta/meta-acadia/recipes-kernel/linux/files/rt/patch-6.6.78-rt51.patch`
   — vendored upstream patch (downloaded from
   `https://cdn.kernel.org/pub/linux/kernel/projects/rt/6.6/patch-6.6.78-rt51.patch.xz`,
   GPG-verified, decompressed; SHA-256 recorded in execution.md).
2. `meta/meta-acadia/recipes-kernel/linux/files/rt/0001-rt51-rpi-fixups.patch`
   — **only if** the upstream patch conflicts with RPi BSP code; upstream patch
   stays untouched, fixups separated.
3. `meta/meta-acadia/recipes-kernel/linux/files/fragments/preempt-rt.cfg`
   — new fragment: `CONFIG_PREEMPT_RT=y` plus explicit unset of the non-RT
   preemption choice values.
4. `meta/meta-acadia/recipes-kernel/linux/linux-raspberrypi_6.6.bbappend`
   — append patch entries to `SRC_URI` (fragment merge still applies after).
5. Optional (decision D1): `linux-raspberrypi-v7_6.6.bbappend` pinning the same
   SRCREV so armv7 boards share the identical 6.6.78 + RT source.
6. Optional (decision D2): `rt-tests` added to `acadia-image`.
7. `CHANGELOG.md` — append entry.

## Affected interfaces

- Shipped kernel image (`kernel_2712.img` / `kernel.img`) and its WIC/SWUpdate
  packaging — content changes, format unchanged.
- SWUpdate A/B and u-boot boot-integrity flow — exercised, not modified.
- acadia-hal / instrumentation recipes — rebuilt by normal dependency graph;
  no recipe change required.

## Local build and test plan

1. `make build rpi5` — full image build; confirm `CONFIG_PREEMPT_RT=y` in the
   merged kernel `.config` and `rt51` in the kernel version string.
2. `make test-wiring` — repo-level consistency checks.
3. Boot RPi 5: `uname -v` contains `PREEMPT_RT`; `/proc/interrupts` threaded;
   `cyclictest -m -p95 -i1000 -h400 -D15m` idle + under `hackbench` load.
4. Peripheral suite from `acadia-base.cfg`: CAN (mcp2515), 1-Wire, PWM, PCF8523
   RTC, PoE fan, bcm2835 watchdog.
5. SWUpdate: install RT image to inactive slot, verify boot selection and
   rollback.

## Role in cross-repository validation

Acadia-OS produces the RT image consumed by the validation-only leaves
(HAL, Instrumentation, Hardware). Their on-target procedures run against the
image built here; evidence is recorded in Acadia-OS `validation.md` and linked
from the parent task.