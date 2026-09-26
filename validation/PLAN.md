# Validation Suite — Plan

Task: post-boot feature validation harness for Acadia-OS (`validation/`).
Owner: Acadia-OS · Status: approved for implementation (user directive,
this session) · Track: IV&V tooling (host-side, no OS feature change)

## Problem statement

Acadia-OS promises a large feature set through `meta/meta-acadia`
(A/B OTA, WebConfig, Instrumentation, hardening, persistence, hardware
enablement, 22 vertical images). After flashing a board there is no single,
extensible way to verify on the bench that *all* promised features are
actually present and operational on the booted image.

## Desired outcome

- A self-contained `validation/` folder with a top-level `Makefile`.
- Python framework (stdlib + paramiko) running on the x86 host, driving the
  booted Pi over SSH with username + password (key auth supported).
- One modular suite per feature area, auto-discovered, trivially extensible.
- Human + machine-readable reports (console table, Markdown, JSON).
- Exit codes suitable for CI and future bench automation.

## Acceptance criteria

1. `make list` lists all suites/groups without a target or paramiko installed.
2. `make setup` creates the venv and installs `paramiko`.
3. `make validate HOST=<ip>` (password prompted) runs the full suite set and
   prints a per-check PASS/FAIL/SKIP/WARN table + totals.
4. Reports land in `validation/reports/` as JSON + Markdown; exit code is 0
   only when nothing failed.
5. Every feature promised by `meta/meta-acadia` on the default `rpi5` board
   is covered by at least one check (see coverage matrix below).
6. Adding a suite requires only a new `tests/t*.py` file.
7. `make lint` passes (`py_compile` over all suite code).

## Coverage matrix (promise → suite)

| meta-acadia promise | Suite |
|---|---|
| os-release identity, PREEMPT_RT kernel, healthy boot | t01 |
| A/B WKS layout (boot/rootfs-a/rootfs-b, /pst, /home, /var/lib/acadia) | t02 |
| Promised packages (middleware, tools, rsyslog, chrony, nftables…) | t03 |
| Promised systemd units active/enabled (services, mounts, timers) | t04, t07, t08 |
| SSH + network interfaces | t05 |
| sshd hardening, nftables firewall, sudoers, locked accounts | t06 |
| Instrumentation istate + spokes (rpi4/5/cm5) | t07 |
| WebConfig daemon/applyd/TLS/polkit | t08 |
| swupdate A/B readiness (daemon, inactive-slot contract, bootcheck) | t09 |
| Hardware enablement (i2c/spi/gpio/uart/pcie/usb/w1/thermal) | t10 |
| Camera/GStreamer/V4L2/DRM/ALSA stack | t11 |
| Time chain (chrony, RTC, rtc-sync) | t12 |
| Persistent journal, rsyslog, dmesg capture | t13 |
| Device identity, factory provisioning, boot integrity, HAL/client | t14 |

## Phases

1. **Architecture** — this document + `ARCHITECTURE.md` (done before code).
2. **Framework** — config/connection/base/results/runner/cli (no features).
3. **Suites t01–t14** — one module per feature area, promise-traceable.
4. **Makefile + README** — `list`, `setup`, `validate`, `smoke`, `report`,
   `lint`, `clean`; usage docs.
5. **Self-check** — `py_compile` + `make list` + `--list` (no device needed);
   device run is a bench exercise for the user.

## Assumptions / exclusions

- Target is reached over TCP/IP (Ethernet or wlan). Default user `rpi`.
- Bench images use password SSH or the user passes `--key`; production
  policy expectations are configurable (`--allow-password-ssh`).
- No destructive actions (OTA install, wipe) — covered by `scripts/hil-ota.sh`
  and factory tooling.
- Serial console capture, multi-device fan-out, and manifest auto-generation
  from the build are future work.