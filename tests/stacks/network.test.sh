#!/usr/bin/env bash
# Network stack integration tests
# Copyright (c) 2026 思捷娅科技 (SJYKJ) | License: MIT

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/docker.sh"
source "$(dirname "$0")/../lib/report.sh"

run_test() {
    local stack="$1" name="$2"; shift 2
    local start
    start=$(date +%s%N)
    if "$@" 2>/dev/null; then
        local dur=$(( ($(date +%s%N) - start) / 1000000 ))
        print_test "$stack" "$name" "PASS" "0.$dur"
        report_record "$stack" "$name" "PASS" "0.$dur"
    else
        local dur=$(( ($(date +%s%N) - start) / 1000000 ))
        print_test "$stack" "$name" "FAIL" "0.$dur"
        report_record "$stack" "$name" "FAIL" "0.$dur"
    fi
}

test_network_all() {
    local compose_file="stacks/network/docker-compose.yml"

    if [[ ! -f "$compose_file" ]]; then
        print_test "network" "Stack not implemented" "SKIP" "0"
        report_record "network" "Stack not implemented" "SKIP" "0"
        ((ASSERT_SKIP++))
        return
    fi

    # Level 1: Compose syntax
    local start
    start=$(date +%s%N)
    if docker compose -f "$compose_file" config --quiet 2>&1; then
        local dur=$(( ($(date +%s%N) - start) / 1000000 ))
        print_test "network" "Compose syntax valid" "PASS" "0.$dur"
        report_record "network" "Compose syntax valid" "PASS" "0.$dur"
        ((ASSERT_PASS++))
    else
        local dur=$(( ($(date +%s%N) - start) / 1000000 ))
        print_test "network" "Compose syntax valid" "FAIL" "0.$dur"
        report_record "network" "Compose syntax valid" "FAIL" "0.$dur"
        ((ASSERT_FAIL++))
    fi

    # Level 1: No :latest tags
    run_test "network" "No latest tags" assert_no_latest_images "stacks/network/"

    # Level 1: All services have healthcheck
    local has_hc=true
    while IFS= read -r svc; do
        local hc
        hc=$(docker compose -f "$compose_file" config \
            --format json 2>/dev/null \
            | jq -r ".services.\"$svc\".healthcheck // empty" 2>/dev/null)
        if [[ -z "$hc" ]]; then
            has_hc=false
            break
        fi
    done < <(docker compose -f "$compose_file" config --services 2>/dev/null)

    if $has_hc; then
        print_test "network" "All services have healthcheck" "PASS" "0"
        report_record "network" "All services have healthcheck" "PASS" "0"
        ((ASSERT_PASS++))
    else
        print_test "network" "All services have healthcheck" "FAIL" "0"
        report_record "network" "All services have healthcheck" "FAIL" "0"
        ((ASSERT_FAIL++))
    fi

    # Level 1+2: Container tests (only if stack is deployed)
    local services
    services=$(docker compose -f "$compose_file" config --services 2>/dev/null)
    for svc in $services; do
        if docker ps --format '{{.Names}}' | grep -q "$svc"; then
            run_test "network" "$svc running" assert_container_running "$svc"
            run_test "network" "$svc healthy" assert_container_healthy "$svc" 60
        fi
    done
}

if [[ "${{BASH_SOURCE[0]}}" == "${{0}}" ]]; then
    print_header
    report_init
    test_network_all
    report_summary
fi
