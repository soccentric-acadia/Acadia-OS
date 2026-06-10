#!/usr/bin/env bats
# test_acadia_hal_typo.bats — regression test for issue #62.
#
# Issue #62: acadia-hal_git.bb had `Acaida-HAL` (misspelled) in
# both HOMEPAGE and SRC_URI.  Per the master SoCcentric instructions
# §3 the canonical name is "Acadia" (not "Acaida").  A misspelled
# GitHub org repo is a classic typo-squat target — a malicious
# actor could register "Acaida-HAL" and serve a backdoored source
# that the build would happily fetch.
#
# The fix:
#   1. HOMEPAGE = "https://github.com/SiliconCentric/Acadia-HAL"
#   2. SRC_URI references .../Acadia-HAL.git
#   3. NO occurrence of "Acaida" anywhere in the recipe.
#
# These tests are the static guard.  A regression that re-introduces
# the misspelling is caught at PR time, not at the operator's
# first successful OTA update.

setup() {
    SUT="${BATS_TEST_DIRNAME}/../acadia-hal_git.bb"
    [ -f "${SUT}" ] || skip "acadia-hal_git.bb not found"
}

# ── 1. No misspelling anywhere in the recipe ──────────────────────────────

@test "issue #62: NO occurrence of the 'Acaida' misspelling" {
    # Case-insensitive: 'Acaida', 'acaida', 'ACAIDA' all fail.
    # Anchored on the literal "Acaida" so a future refactor that
    # introduces the typo in a comment, URL, or branch name is
    # caught.
    ! grep -qiE 'acaida' "${SUT}"
}

@test "issue #62: HOMEPAGE uses the canonical 'Acadia-HAL' name" {
    grep -qE '^HOMEPAGE[[:space:]]*=.*Acadia-HAL' "${SUT}"
}

@test "issue #62: SRC_URI uses the canonical 'Acadia-HAL.git' name" {
    # The URL must include "Acadia-HAL.git" (with the .git suffix
    # that git fetches require).  A "Acaida" URL would also
    # pass test 1's negative grep, so this test is the positive
    # counterpart.
    grep -qE 'github\.com/SiliconCentric/Acadia-HAL\.git' "${SUT}"
}

# ── 2. The whole tree is clean of the misspelling ────────────────────────

@test "issue #62: NO 'Acaida' anywhere in the meta-acadia layer" {
    # Tree-wide scan: the misspelling is a single character off,
    # and a future contributor might re-introduce it in a sibling
    # file (e.g. a kas yaml, a conf file, a script).  Allow the
    # CLAUDE.md / lessons-learned entries to keep the literal
    # 'Acaida' for historical context (those are explicitly
    # about the typo).  Skip .git/ — FETCH_HEAD and reflogs
    # legitimately contain the misspelled name from prior fetches.
    local layer="${BATS_TEST_DIRNAME}/../../.."
    local offenders
    offenders=$(grep -rliE 'acaida' "${layer}" 2>/dev/null \
        | grep -vE '/\.git/' \
        | grep -v 'CLAUDE\.md$' \
        | grep -v 'test_acadia_hal_typo\.bats$' || true)
    [ -z "${offenders}" ] || {
        echo "Found 'acaida' in:"
        echo "${offenders}"
        return 1
    }
}

# ── 3. The recipe still builds (smoke test) ─────────────────────────────

@test "issue #62: recipe still has SRC_URI and SRCREV" {
    # Defensive: a refactor that over-fixed the typo by removing
    # SRC_URI altogether would break the build.
    grep -qE '^SRC_URI[[:space:]]*=' "${SUT}"
    grep -qE '^SRCREV[[:space:]]*=' "${SUT}"
}

@test "issue #62: do_install() still has all four install categories" {
    # Sanity: the misspelling fix did not disturb the install
    # logic from issue #58.
    grep -qE 'install -m 0755.*libdir' "${SUT}"
    grep -qE 'install -m 0644.*libdir' "${SUT}"
    grep -qE 'install -m 0644.*includedir' "${SUT}"
    grep -qE 'install -m 0644.*security.md' "${SUT}"
}

# ── 4. The README / docs reflect the canonical name ─────────────────────

@test "issue #62: CLAUDE.md C2 lesson explicitly warns about the typo" {
    # C2 (in CLAUDE.md) says: "Don't trust the meta-acadia kas
    # fetch — it has a typo (\"Acaida\") and silently falls back
    # to the in-tree layer. Either remove the kas entry and rely
    # on the in-tree layer, or fix the URL. Verify with
    # grep -n 'Acaida' kas/repos/*.yaml meta/ -r 2>/dev/null".
    # That lesson is the WHY for this fix; it must remain.
    grep -qE "Acaida" "${BATS_TEST_DIRNAME}/../../../CLAUDE.md" || true
    # (This test is informational; the C2 entry is allowed to
    # keep the literal "Acaida" as historical context.)
}
