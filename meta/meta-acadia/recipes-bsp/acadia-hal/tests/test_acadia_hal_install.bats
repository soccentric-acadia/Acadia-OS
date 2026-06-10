#!/usr/bin/env bats
# test_acadia_hal_install.bats — regression test for issue #58.
#
# Issue #58: the previous acadia-hal_git.bb do_install had
# `find ${S}/src -name "*.h" -o -name "*.hpp" | while read f`.  The
# `-o` operator binds to the *preceding* `-name`, so the find
# expression was effectively `(-name "*.h") -o (rest of the shell
# pipeline)`.  The result: only *.h files were installed into the
# dev package; *.hpp files were silently dropped.
#
# The fix:
#   1. Parenthesise the -o group so the precedence is explicit:
#      `find ${S}/src \( -name "*.h" -o -name "*.hpp" \)`
#   2. Use -print0 / xargs -0 to handle paths with spaces (defensive
#      for future layout changes).
#   3. Document that upstream CMakeLists.txt install-rules would
#      let this loop disappear entirely (issue #48 follow-up).
#
# These tests are the static guard that catches a regression to
# the unparenthesised -o bug.

setup() {
    SUT="${BATS_TEST_DIRNAME}/../acadia-hal_git.bb"
    [ -f "${SUT}" ] || skip "acadia-hal_git.bb not found"
}

# ── 1. The parenthesised -o group is in place ─────────────────────────────

@test "issue #58: find expression for headers is parenthesised" {
    # The bug pattern: `find ... -name "*.h" -o -name "*.hpp"`
    # without parens.  The fix: `find ... \( -name "*.h" -o -name "*.hpp" \)`
    # The grep below requires the literal `\( ... -o ... \)` group
    # around the two -name predicates.
    grep -qE '\\\([[:space:]]*-name[[:space:]]+"\*\.h"[[:space:]]+-o[[:space:]]+-name' "${SUT}"
}

@test "issue #58: find expression matches BOTH *.h and *.hpp" {
    # Defensive: the regex must include both -name "*.h" and
    # -name "*.hpp" (or the equivalent wildcard).  If a future
    # refactor narrows the glob, the regression returns.
    local find_line
    # Find the find command that has -name (not the -name in
    # an `if(NOT ...)` or other context).  Restrict to lines
    # with the -print0 / xargs -0 / -exec that mark the new code.
    find_line=$(grep -E '^[[:space:]]*find[[:space:]].*\(.*-name.*\).*-print0' "${SUT}" | head -1)
    [ -n "${find_line}" ]
    [[ "${find_line}" == *'-name "*.h"'* ]]
    [[ "${find_line}" == *'-name "*.hpp"'* ]]
}

# ── 2. No unparenthesised -o left anywhere in do_install ─────────────────

@test "issue #58: no unparenthesised -name -o -name pattern remains" {
    # The literal buggy form: -name "*.h" -o -name "*.hpp" with no
    # group delimiters in between.  After the fix, the -o must
    # be inside \( ... \).  Catch a regression that re-introduces
    # the unparenthesised form on a different line.
    ! grep -qE '^[[:space:]]*find[[:space:]]+.*-name[[:space:]]+"?\*\.[hp]p\?"?[[:space:]]+-o[[:space:]]+-name' "${SUT}"
}

# ── 3. xargs -0 / -print0 used (defensive) ───────────────────────────────

@test "issue #58: header install uses -print0 / xargs -0 (or -exec)" {
    # The original used a shell `while read` loop.  The fix uses
    # -print0 / xargs -0.  Either is fine; what we want to *forbid*
    # is the read-loop pattern, which breaks on filenames with
    # spaces.
    local loop_pattern
    loop_pattern=$(grep -E 'find.*-name.*\|[[:space:]]*while[[:space:]]+read' "${SUT}" || true)
    [ -z "${loop_pattern}" ] || {
        echo "Found find|while read pattern (breaks on spaces in filenames):"
        echo "${loop_pattern}"
        return 1
    }
    # And the fix must be present in some form:
    grep -qE '(-print0|xargs -0|-exec install)' "${SUT}"
}

# ── 4. The do_install function exists ────────────────────────────────────

@test "issue #58: do_install() is defined" {
    grep -qE '^do_install\(\)[[:space:]]*\{' "${SUT}"
}

@test "issue #58: do_install installs *.so, *.a, headers, and the security doc" {
    # The four categories: shared libs, static libs, headers, doc.
    # A future refactor that drops one would leave the dev package
    # incomplete.  Each line uses an install -m invocation.
    grep -qE 'install -m 0755.*libdir' "${SUT}"
    grep -qE 'install -m 0644.*libdir' "${SUT}"
    grep -qE 'install -m 0644.*includedir' "${SUT}"
    grep -qE 'install -m 0644.*security.md' "${SUT}"
}

# ── 5. Comment explains the upstream-patch path ─────────────────────────

@test "issue #58: comment notes the upstream CMakeLists install-rules follow-up" {
    # The cleanest fix is to add install(TARGETS ...) to upstream
    # CMakeLists.txt and call oe_runmake install.  Until that
    # lands, this loop is the workaround.  A future contributor
    # who reads the recipe should see the path forward.
    grep -qE 'CMakeLists.*install|install.*CMakeLists' "${SUT}"
}
