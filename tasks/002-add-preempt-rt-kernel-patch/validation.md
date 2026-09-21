# Task 002 validation — Add PREEMPT_RT patch to the Linux kernel (Acadia-OS)

- **Date:** 2026-09-21
- **Status:** build-side complete; on-target pending hardware

## Commands and evidence

| # | Command | Revision | Result |
|---|---|---|---|
| 1 | `git apply --check rt51.patch` (post-BSP-patch tree) | SRCREV `bba53a1` (6.6.78) | clean, exit 0 |
| 2 | `make build rpi5` | meta-acadia `4af0d5a` | 10,128/10,128 tasks OK |
| 3 | grep PREEMPT in merged `.config` | — | `CONFIG_PREEMPT_RT=y`, others unset |
| 4 | `strings Image \| grep "Linux version"` | deploy `20260921181301` | `6.6.78-rt51-v8-16k … #1 SMP PREEMPT_RT` |
| 5 | image manifest grep | acadia-image rootfs | `rt-tests 2.6` + ptest present |
| 6 | `make test-wiring` | Acadia-OS | OK (2 pre-existing warnings) |
| 7 | `do_kernel_configcheck` log grep | — | no preempt/fragment warnings |

Artifacts: `deploy/images/rpi5_20260921_111255/` (wic.bz2, bmap, SHA256SUMS).

## Pending on-target procedure (owner: platform team)

Image ready at `deploy/images/rpi5_20260921_111255/`. Flash, then:

```sh
uname -v                          # expect "... SMP PREEMPT_RT"
dmesg | head -5                   # RT banner
cyclictest -m -p95 -i1000 -h400 -D15m   # idle; then under: stress-ng --cpu 4
# peripheral suite: candump/cansend can0, 1-Wire read, PWM, hwclock, PoE fan,
# watchdog kick — per acadia-base.cfg hardware checklist
# SWUpdate: swupdate to inactive slot, verify boot + rollback
```

Gate (D3): cyclictest max ≤ 500 µs/core under load. Record results here and in
the parent `validation.md` before closing the task.