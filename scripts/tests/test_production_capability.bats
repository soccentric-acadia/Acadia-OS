#!/usr/bin/env bats

setup() {
    ROOT="${BATS_TEST_DIRNAME}/../.."
}

@test "rpi5 production board matches the hardware capability matrix" {
    run "${ROOT}/scripts/check-production-capability.sh" rpi5 "${ROOT}/kas/boards/rpi5.yaml"
    [ "$status" -eq 0 ]
    [ "$output" = "production hardware capability: OK (rpi5, rpi5-cm5-bom-rev-c)" ]
}

@test "unsupported board is rejected before a production build" {
    run "${ROOT}/scripts/check-production-capability.sh" rpi4 "${ROOT}/kas/boards/rpi5.yaml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"unsupported by hardware capability matrix"* ]]
}
