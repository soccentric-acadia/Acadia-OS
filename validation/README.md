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
make setup                    # once: venv + paramiko
make validate HOST=192.168.1.50          # password prompted
make validate HOST=192.168.1.50 PASS='secret' USER=rpi
make smoke HOST=192.168.1.50  # fast core subset
```

Reports land in `reports/report-<ts>-<host>.{json,md}`; exit code is 0 only
when nothing failed (2 = device unreachable, 1 = failed checks; with
`STRICT=1` skips also fail — CI mode).

## Selecting suites

```bash
make validate HOST=... GROUPS=hardware,ota   # by group
make validate HOST=... ONLY=t01,services     # by suite name/number
make validate HOST=... EXCLUDE=multimedia
python3 -m acadia_validation --list          # all suites
```

Groups: `core boot storage packages services network security
instrumentation webconfig ota hardware multimedia time logging identity`.

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