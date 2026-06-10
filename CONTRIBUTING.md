# Contributing to Acadia OS

Thank you for contributing to the Acadia OS Yocto/OpenEmbedded build
system.  This document captures the conventions every contributor must
follow.  The conventions are short, deliberate, and enforced by
regression tests in `meta/meta-acadia/recipes-*/tests/`.

The master SoCcentric instructions apply on top of this file —
see `~/.claude/CLAUDE.md` (§11 in particular).  Local conventions here
layer on top of the master rules; on any conflict, the master rules
win.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Workflow Overview](#workflow-overview)
3. [Patch Conventions](#patch-conventions)
4. [Recipe Conventions](#recipe-conventions)
5. [Service Unit Conventions](#service-unit-conventions)
6. [Bats Test Conventions](#bats-test-conventions)
7. [Commit & PR Conventions](#commit--pr-conventions)
8. [Documentation Conventions](#documentation-conventions)
9. [Common Pitfalls](#common-pitfalls)

---

## Code of Conduct

Be precise, be defensive, leave the layer cleaner than you found it.
This is a supply-chain-adjacent project (§1 ISO 26262 / IV&V) — every
change has audit and traceability implications.  When in doubt, open
an issue and ask.

---

## Workflow Overview

The "fix bugs" workflow (master SoCcentric §8) is the canonical path:

1. Pick an open issue (or open one with a clear defect description).
2. Add the `in-progress` label, post a "Started. Branch: `fix/NN-…`"
   comment on the issue.
3. Branch: `git checkout develop && git pull && git checkout -b fix/NN-slug`.
4. **Baseline build first.**  If the baseline fails, STOP and report.
5. Fix — smallest possible change.  No drive-by edits, no refactors.
6. Validate — build + tests + lint.
7. Rebase onto `origin/develop`; re-validate.  Never push red.
8. Push & PR: `gh pr create --base develop --title "fix: <desc> (#NN)"`.
9. Record Do/Don't lessons in `CLAUDE.md` (§11 master SoCcentric).

Issue titles follow the master SoCcentric §7 standard:

```
[<component>][<category>] <short description>
e.g. [HAL][memory-safety] Buffer overflow in spi_read()
```

Categories: `bug`, `memory-safety`, `concurrency`, `build`, `security`,
`perf`, `docs`, `test`, `improvement`.

---

## Patch Conventions

Patches under `meta/meta-acadia/recipes-*/<recipe>/files/` follow the
Yocto convention:

- **Filename:** `NNNN-verb-noun-phrase.patch`
  - `NNNN` is the next 4-digit number in the recipe's `files/` directory.
  - `verb` is present-tense ("fix", "add", "disable").
  - `noun-phrase` is concise, kebab-case, ASCII.
  - Good: `0001-fix-grpc-cpp-plugin-cross-compile.patch`.
  - Bad: `fix.patch`, `grpc_cpp_plugin_fix.patch`,
    `0001-cross-compile-fix.patch` (vague).

- **Header (in that order):**
  ```
  From: <Author Name> <author@example.com>
  Subject: [PATCH] <imperative-mood summary, ≤ 72 chars>

  <Body — what and why, not how.  Reference issue numbers.>

  Upstream-Status: Pending | Inappropriate [reason] | Submitted [...]
  Signed-off-by: <Name> <email>
  ```

- **`Upstream-Status` is required.** Use one of:
  - `Pending` — patch is on its way upstream, not yet merged.
  - `Inappropriate [reason]` — patch will not go upstream.  Reason
    examples: `cross-compile workaround`, `private configuration`,
    `vendor-specific init`.  Be specific.
  - `Submitted [<upstream-issue-url>]` — patch sent upstream; URL
    is the upstream bug/PR.

- **`do_configure:prepend` sed-isms are forbidden for new work.**
  Use a `SRC_URI` patch instead.  The sed pattern is fragile to
  upstream drift and is bypassed by BitBake's QA.  Existing
  in-recipe seds (e.g. `acadia-hal_git.bb`) are being migrated
  to patches as upstream code is cached in-tree (issue #48).

- **Do not edit upstream Yocto / BSP layers** (master SoCcentric
  §1, "NEVER patch upstream Yocto/BSP layers").  All OS-layer
  changes go in `meta/meta-acadia/`.

---

## Recipe Conventions

- **`LIC_FILES_CHKSUM` is mandatory** — even for `LICENSE = "CLOSED"`.
  The recipe file itself is an acceptable check target
  (`file://${COREBASE}/../meta/meta-acadia/<recipe>.bb;md5=<…>`)
  with a literal md5 placeholder.  BitBake re-validates on every
  build, so the placeholder is fine; a real `LICENSE` file's
  checksum should replace it when upstream publishes one.

- **`SRCREV` must be pinned to a 40-char SHA** — never `${AUTOREV}`
  for production.  `AUTOREV` is acceptable for development under
  a `dev` image recipe, never for the production `acadia-image`.
  See master SoCcentric §1 reproducibility requirements.

- **Pin external layer commits to SHAs** in `kas/repos/*.yaml`.  No
  `commit: HEAD`; no `branch:` only.

- **`do_install` shell loops are fragile** (master SoCcentric
  C2, issue #58).  Prefer:
  - `install(TARGETS …)` / `install(DIRECTORY …)` rules in
    upstream CMakeLists.txt, then `oe_runmake install`.
  - `find ... -print0 | xargs -0 -I {} install -m … {} …` for
    manual fallback.  Never `while read f; do install "$f" …; done`
    (breaks on filenames with spaces).
  - `find` `-o` groups MUST be parenthesised.  The unparenthesised
    form silently drops the second `-name` pattern (issue #58).

- **`install -d -o` / `install -g` is forbidden in first-boot
  scripts.**  BusyBox's `install` silently ignores both flags;
  the result is `root:root` ownership and the user can't log in
  (issue #44).  Use `mkdir -m 0750` + `chown` explicitly.

- **`INSANE_SKIP` is a last resort**, not a default.  When you skip
  a QA check, document the reason in a comment.  Suppressing QA
  on `-dev` masks packaging bugs in that package (issue #52).

---

## Service Unit Conventions

- **Use `Requires=`, not just `Wants=`, for hard-lifecycle
  dependencies** (issue #46).  `Wants=` is a soft preference;
  if the wanted unit is missing or failed, the wanter starts
  anyway.  `Requires=` fails the dependent on missing / failed
  required unit.  Keep `Wants=` *additionally* for activation
  order; both are needed.

- **Use `BindsTo=` for lifetime-tied units.**  `After=` only
  orders start; `BindsTo=` stops the bound unit when the
  referent dies.  The two are complementary, not substitutes
  (issue #46).

- **`RemainAfterExit=yes` is load-bearing on `Type=oneshot`**
  services.  Without it, the service is "inactive" after success
  and `BindsTo=` consumers will see the referent as "failed".

- **Anchor all paths in `find`, `lsblk`, `findmnt` calls on
  `/sys/class/block/<dev>` patterns, not on device-name regexes**
  (issues #42, #54).  Block-device names are kernel-assigned and
  change between SD, NVMe, and USB boot.

- **Order units on the *socket*, not the network.**  Don't gate
  on `network-online.target` for services that should fire at
  boot (master SoCcentric C1, issues #29, #57).  A dead uplink
  is a normal lab state, not a failure.

- **Diagnostic data goes to the journal, not `/var/log/`**
  (issue #56).  `/var/log` is a symlink to `/var/volatile/log`
  in Poky by default; data there is lost on reboot.  Pipe to
  `systemd-cat -t <tag> -p <prio>` instead.

---

## Bats Test Conventions

- **Every recipe and service unit has a sibling `tests/`
  directory** with at least one `*.bats` file
  (`test_<recipe>.bats` or `test_<unit>.bats`).

- **Tests are static guards**, not unit tests with mocks.  Most
  Acadia-OS tests grep-assert on file contents, run with a
  stub `BIN` directory prepended to `PATH`, and verify the
  script's effect on a fake sysfs / fake `/boot`.  See
  `recipes-core/acadia-services/tests/test_dmesg_capture_service.bats`
  for the canonical pattern.

- **Anchor every grep that guards a config-file patch** (master
  SoCcentric C6).  Unanchored grep matches comments and
  substrings.  Use `^[[:space:]]*Directive[[:space:]]+` to
  match the directive *as written*.

- **Test the regression in BOTH directions** (master SoCcentric
  C4, C6).  A test that only covers the bug is incomplete;
  add the inverse test that covers the opposite regression.

- **Path math uses `${BATS_TEST_DIRNAME}/../../..`**, not
  `$(git rev-parse --show-toplevel)`.  A test must work on
  a CI checkout and a dev worktree.

- **Stub commands in `setup()`, not at file top** (master
  SoCcentric C9).  bats runs gather at parse time, before
  any test's `setup()`.

- **A skip is a signal "this checkout is unexpected"; a fail
  is a signal "the test is broken"** (master SoCcentric C11).
  Don't `skip` a test for a path-math error — fix the math.

- **Walk the whole tree in static regression tests** (master
  SoCcentric C11).  Catching a regression in any script is
  the point; a test that only inspects one file is blind
  to upstream / downstream wiring.

---

## Commit & PR Conventions

- **Conventional Commits.**  Prefix: `fix:`, `feat:`, `docs:`,
  `chore:`, `refactor:`, `test:`, `build:`, `ci:`.  Scope
  is the recipe or unit: `fix(expand-rootfs): …`, `docs(layer):
  …`, `ci(workflow): …`.

- **One issue, one branch, one PR.**  No bundling, no drive-bys.
  The §8 master workflow says "smallest possible change that
  resolves the issue."

- **PR body must include:**
  - Problem statement (what was broken, what the user saw).
  - Fix description (what changed, why this approach).
  - Validation evidence (test results, build output).

- **Rebase before push.**  `git fetch origin develop && git
  rebase origin/develop` linearises the history and forces a
  re-validation pass.

- **End commit messages with the Co-Authored-By line** (project
  convention):

  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  ```

- **End PR bodies with the Claude Code attribution:**

  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  ```

---

## Documentation Conventions

- **`CLAUDE.md` is the local lessons log.**  Every fix appends
  a `C<n>` section with Do/Don't bullets (master SoCcentric §11).
  The convention is short — each bullet is one observation, not
  a paragraph.  Before appending, check for an equivalent
  entry and *update*, don't duplicate.

- **Comments in code are non-obvious decisions, not
  restatements.**  A comment that says "this loops over all
  files" is noise; a comment that says "the find -o MUST be
  parenthesised or the second -name is silently dropped
  (issue #58)" is documentation.  Default to fewer comments
  that say more.

- **Issue references in code**: include the issue number in
  the comment that explains a non-obvious choice:

  ```bash
  # Issue #42: lsblk + /sys/class/block is portable across
  # mmcblk, nvme, sd, vd.  Don't regex-parse the dev name.
  DISK_NAME=$(lsblk -ndo PKNAME "${ROOT_DEV}" 2>/dev/null || true)
  ```

---

## Common Pitfalls

- **Don't hardcode RPi 5 kernel/DTB names** in the `swu` target
  Makefile (master SoCcentric C2, issue #63).  RPi 4 uses
  `kernel_2711.img` / `bcm2711-rpi-4-b.dtb`; RPi 3 uses
  `kernel_2710.img` / `bcm2710-rpi-3-b.dtb`.  Derive from
  `MACHINE` or expose overridable Make variables.

- **Don't `source` any file from a writable mount** (master
  SoCcentric C3).  `/boot` is FAT32 and chmod-666 from the
  running system.  `source` is arbitrary code execution as
  root, no matter what `set -e` is set to.  Use a `while
  IFS='=' read` loop.

- **Don't `set -e` through `source <config>`** (master SoCcentric
  C2).  The config is parsed as a shell script; any line that
  looks like a command aborts.  Use a read loop.

- **Don't `set -e` with `findmnt -no SOURCE /`** (master
  SoCcentric C9).  Use a robust read or, better, derive the
  parent disk from `lsblk PKNAME`.

- **Don't trust HEAD-tracking git sources** in production
  (master SoCcentric §1).  Pin SHAs.

- **Don't bundle cross-platform / cross-project changes in one
  commit** (master SoCcentric §5).  Blast radius = one project
  per approved change.  If a fix needs matching changes in
  another project, list them in the PR body, don't include
  them in the commit.

- **Don't use `ALLOW_EMPTY` + empty `FILES:${PN} = ""` to
  ship a "dev-only" package** (master SoCcentric C2).  Use a
  `-dev` split package.

- **Don't use `INSANE_SKIP` as a substitute for fixing the
  defect** (master SoCcentric C2, issue #52).  Suppressing QA
  on `-dev` masks real packaging bugs in that package.

- **Don't commit secrets** (master SoCcentric §1).  Auth is
  `GH_TOKEN` env var only.

- **Don't use git submodules** (master SoCcentric §1).  No
  `.gitmodules`, no `git submodule` commands.  Ever.

- **Don't modify `*-Hardware` repos** (master SoCcentric §1).
  Read-only design context.

---

## Getting Help

- **Master SoCcentric instructions** — `~/.claude/CLAUDE.md` is
  the system-wide contract.
- **Local lessons** — `CLAUDE.md` in the repo root has the
  `C1`…`Cn` Do/Don't entries from past fixes.
- **Open issues** — `gh issue list --state open` is the queue
  of known defects, ordered by severity within label.
- **PRs** — `gh pr list --state open` shows what's in flight.

If something here conflicts with the master SoCcentric
instructions, the master wins — flag the conflict on the PR.
