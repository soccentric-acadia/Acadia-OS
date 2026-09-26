# Acadia Validation Suite — Usage

Post-boot feature validation for Acadia-OS images. Runs on the x86 host;
drives the booted Raspberry Pi over SSH (username + password by default).
Every check traces to a promise made by `meta/meta-acadia` — see
[ARCHITECTURE.md](ARCHITECTURE.md) for the design and [PLAN.md](PLAN.md)
for scope and coverage matrix.

## Quick start

```bash
cd validation
make list                     # see suites and groups
make list -- --trace          # promise→check traceability map
make setup                    # once: venv + paramiko + pyserial
make validate HOST=192.168.1.50          # password prompted
make validate HOST=192.168.1.50 PASS='secret' USER=rpi
make validate HOST=192.168.1.50 MANIFEST=manifest.json   # paired to build
make smoke HOST=192.168.1.50  # fast core subset
```

Reports land in `reports/report-<ts>-<host>.{json,md}`; exit code is 0 only
when nothing failed (2 = device unreachable, 1 = failed checks; with
`STRICT=1` skips also fail — CI mode). `--verbose` streams every check as
it runs; `--diff A.json B.json` compares two reports (exit 1 on
regressions).

## Selecting suites

```bash
make validate HOST=... GROUPS=hardware,ota   # by group
make validate HOST=... ONLY=t01,services     # by suite name/number
make validate HOST=... EXCLUDE=multimedia
python3 -m acadia_validation --list          # all suites
python3 -m acadia_validation --list --trace  # + promise→check map
```

Groups: `core boot storage packages services network security
instrumentation webconfig ota hardware multimedia time logging identity
rt`.

## SSH authentication

- **Password (default):** pass `PASS=...` or let it prompt.
- **Key (production-hardened image):** `KEY=~/.ssh/id_ed25519`.
- The shipped image hardening (`acadia-hardening.conf`) sets
  `PasswordAuthentication no` — a bench image used with passwords must
  enable password auth (or add `--allow-password-ssh` to only WARN about
  the deviation instead of failing the sshd-policy check).

The suite runs privileged checks with passwordless `sudo -n` when the
target allows it; without sudo those checks degrade to evidence-based or
SKIP — never a crash.

## Pairing to a build (manifest)

After `make build && make deploy-images` in the repo root:

```bash
make manifest                     # reads newest deploy/images/<board>_<ts>
make validate HOST=... MANIFEST=manifest.json
```

The manifest carries the built package list (from the Yocto rootfs
`.manifest`), machine, and os-release VERSION_ID. `t03` then diffs
*actual vs declared* packages and `t01` pairs the booted image with the
build — no more frozen recipe copies drifting out of sync.

## Fleet mode

```bash
# fleet.txt (chmod 600, gitignored):  host user password [keypath]
192.168.1.50 rpi secret
192.168.1.51 rpi secret
make validate-all INVENTORY=fleet.txt PARALLEL=2 [GROUPS=] [MANIFEST=]
```

Every target runs the same selection; you get a per-host ✓/✗ line and an
aggregated `reports/fleet-<ts>.json`. Exit 1 on any failure or unreachable
target.

## Serial boot check (SSH cannot see the boot)

```bash
make serial PORT=/dev/ttyUSB0 BAUD=115200 TIMEOUT=120 [REBOOT_CMD='...']
```

Passive UART watcher: kernel output, panic/oops scan, login prompt within
the timeout. `REBOOT_CMD` (power relay / ssh reboot) makes it repeatable.

## Timing budgets

`t15_rt_diagnostics` measures instead of assuming: boot-to-userspace
(`--boot-budget`, default 180 s) and a bounded 10 s `cyclictest` Avg
latency (`--latency-budget`, default 1000 µs) — that is what `rt-tests`
ships for.

## Privileged checks (sudo)

Privileged checks (`sshd -T`, `nft list ruleset`, `cyclictest -m`,
`rpicam-still`, `rpi-eeprom-update`) probe passwordless `sudo -n` once and
degrade to evidence/SKIP without it. For a complete run, give the bench
SSH user a NOPASSWD sudoers drop-in — the shipped `acadia-sudoers` only
opens specific paths for the apply daemon, not the bench user:

```conf
# /etc/sudoers.d/acadia-validation (bench only)
rpi ALL=(root) NOPASSWD: /usr/sbin/sshd, /usr/sbin/nft, /usr/bin/cyclictest, /usr/bin/rpicam-still, /usr/bin/rpi-eeprom-update
```

## Result statuses

| Status | Meaning |
|---|---|
| PASS | promise verified |
| FAIL | promise broken — counts toward exit code |
| SKIP | not applicable / environment condition (reason recorded) |
| WARN | passed with a noteworthy observation |

## Extending

Add `acadia_validation/tests/t<NN>_<feature>.py` with a `FeatureSuite`
subclass and `check_*` methods — discovery, filtering, Makefile and reports
pick it up automatically. Trace each check to its promise (recipe/task) in
a comment.

## Out of scope (by design)

Destructive flows (OTA install + rollback, factory wipe) are covered by
`scripts/hil-ota.sh` and factory tooling; this suite only validates
standing promises on a booted image.