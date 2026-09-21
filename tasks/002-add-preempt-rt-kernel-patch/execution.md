# Task 002 execution — Add PREEMPT_RT patch to the Linux kernel (Acadia-OS)

- **Approval date:** 2026-09-21
- **Approved scope:** aarch64 only (rpi5, cm5, rpi4-64, rpi3-64, rpi0-2w-64);
  `rt-tests` shipped; latency gate ≤ 500 µs. 32-bit armv7 excluded (D1).
- **Status:** build-side complete; on-target pending hardware (see validation.md)

## Implementation checklist

- [x] Record approved scope (D1 resolved: aarch64 only)
- [x] Verify kernel base: SRCREV `bba53a117a4a5c29da892962332ff1605990e17a`
      = Linux 6.6.78 (`work-shared/raspberrypi5/kernel-source`)
- [x] Dry-run RT patch against post-BSP-patch source: clean (`git apply --check`)
- [x] Vendor `files/rt/patch-6.6.78-rt51.patch` (+ `.sign`) into meta-acadia
- [x] Add `files/fragments/preempt-rt.cfg`
- [x] Extend `linux-raspberrypi_6.6.bbappend` SRC_URI (patch + fragment)
- [x] Add `rt-tests` to `acadia-image.bb`
- [x] Commit meta-acadia `4af0d5a` (local; push is a follow-up)
- [x] `make build rpi5`: linux-raspberrypi do_patch → **RT patch applied**;
      do_kernel_configme merged fragment; merged `.config`:
      `CONFIG_PREEMPT_RT=y`, `# CONFIG_PREEMPT/LAZY/VOLUNTARY/NONE not set`;
      do_kernel_configcheck: no warnings
- [x] do_compile → do_deploy → image/WIC/SWU packaging completes (10,128 tasks OK;
  deployed `Image` banner `6.6.78-rt51-v8-16k … #1 SMP PREEMPT_RT`;
  rt-tests 2.6 in image manifest)
- [ ] On-target: boot identity (`uname -v` PREEMPT_RT), `/proc/interrupts`
      threaded, cyclictest idle + loaded, peripheral suite (CAN, 1-Wire, PWM,
      RTC, PoE fan, watchdog), SWUpdate A/B install + rollback
- [x] validation.md recorded (build-side; on-target entries pending)

## Files actually changed

See parent execution.md — all changes live in the meta-acadia layer
(nested clone). No Acadia-OS (outer repo) files modified.

## Implementation decisions

- The RT patch is listed last in SRC_URI:append → applied after all RPi BSP
  patches in do_patch (matches the dry-run verification state).
- No `threadirqs` cmdline added: with PREEMPT_RT, forced IRQ threading is
  default; base config already has IRQ_FORCED_THREADING=y.
- RT kernel remains 6.6.78 — the wic/`kernel_2712.img` names and SWUpdate flow
  are unchanged.

## Commands run

- `curl -O` patch + signature from kernel.org; `gpg --verify`;
  `sha256sum`; `xz -dk`; `git apply --check`; `make build rpi5`.