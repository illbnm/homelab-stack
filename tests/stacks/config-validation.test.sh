#!/usr/bin/env bash
assert_suite "config-validation"

STACKS_DIR="$(cd "$(dirname "$0")/../../.." && pwd)/stacks"

test_compose_syntax_all() {
    assert_test "all compose files have valid syntax"
    local failed=0
    for f in $(find "$STACKS_DIR" -name 'docker-compose.yml' -not -path '*/test*' 2>/dev/null); do
        if ! docker compose -f "$f" config --quiet 2>/dev/null; then
            echo "    FAIL: $f"
            (( failed++ )) || true
        fi
    done
    if [[ "$failed" -eq 0 ]]; then
        _pass
    else
        _fail "$failed compose files have syntax errors"
    fi
}

test_no_latest_tags() {
    assert_no_latest_images "$STACKS_DIR"
}

test_all_services_have_healthcheck() {
    assert_test "all services have healthcheck"
    local missing=0
    for f in $(find "$STACKS_DIR" -name 'docker-compose.yml' -not -path '*/test*' 2>/dev/null); do
        local services
        services=$(docker compose -f "$f" config --services 2>/dev/null || echo "")
        for svc in $services; do
            local hc
            hc=$(docker compose -f "$f" config 2>/dev/null | jq -r ".services[\"$svc\"].healthcheck" 2>/dev/null || echo "null")
            if [[ -z "$hc" || "$hc" == "null" ]]; then
                (( missing++ )) || true
                echo "    Missing: $(basename "$(dirname "$f")")/$svc"
            fi
        done
    done
    if [[ "$missing" -eq 0 ]]; then
        _pass
    else
        _fail "$missing services missing healthcheck"
    fi
}

test_all_env_examples_exist() {
    assert_test "all stacks have .env.example"
    local missing=0
    for dir in "$STACKS_DIR"/*/; do
        if [[ ! -f "$dir/.env.example" && -f "$dir/docker-compose.yml" ]]; then
            (( missing++ )) || true
            echo "    Missing: $dir.env.example"
        fi
    done
    if [[ "$missing" -eq 0 ]]; then
        _pass
    else
        _fail "$missing stacks missing .env.example"
    fi
}

test_compose_syntax_all
test_no_latest_tags
test_all_services_have_healthcheck
test_all_env_examples_exist