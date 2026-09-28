#!/usr/bin/env bats

setup() {
    ROOT="${BATS_TEST_DIRNAME}/../.."
}

@test "release source lock matches the release build configuration" {
    run "${ROOT}/scripts/check-release-sources.sh"
    [ "$status" -eq 0 ]
    [ "$output" = "release source lock: OK" ]
}
