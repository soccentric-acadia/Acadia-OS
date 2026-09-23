#!/usr/bin/env bats
# T-P08 (K04, SB-7): the OTA health contract must not gate on the un-provisioned
# IV&V client. On a production unit /etc/acadia/client.conf is never written,
# so requiring acadia-client.service there rolled back every update. The
# contract is: hal/webconfigd/instr-istate unconditional, acadia-client
# conditional on a provisioned config.

setup() {
    SUT="$BATS_TEST_DIRNAME/../../meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/swupdate-bootcheck.sh"
}

@test "health loop: unconditional set is hal/webconfigd/instr-istate" {
    grep -q 'for unit in hal.service webconfigd.service instr-istate.service;' "$SUT"
}

@test "health loop: acadia-client no longer in the unconditional set" {
    run sed -n '/^for unit in /,/^done/p' "$SUT"
    [[ "$output" != *acadia-client* ]]
}

@test "acadia-client is health-gated only with /etc/acadia/client.conf present" {
    grep -q 'list-unit-files acadia-client.service' "$SUT"
    grep -q '\[\[ -f /etc/acadia/client.conf \]\]' "$SUT"
    # the conditional must gate the same wait_service path
    run awk '/client.conf \]\]/,/^fi$/' "$SUT"
    [[ "$output" == *wait_service*"acadia-client.service"* ]]
}

@test "health contract references T-P08 rationale" {
    grep -q 'T-P08 (K04)' "$SUT"
}

@test "bootcheck script stays bash-clean" {
    bash -n "$SUT"
}