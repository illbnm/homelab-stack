#!/bin/bash
# run-tests.sh - HomeLab Stack 集成测试入口
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

show_help() {
    cat << EOF
HomeLab Stack Integration Tests

用法：$0 [选项]

选项:
  --stack <name>    运行指定 stack 测试 (base, media, etc.)
  --all             运行所有测试
  --help            显示帮助

示例:
  $0 --stack base
  $0 --all
EOF
}

run_stack_tests() {
    local stack="$1"
    local test_file="$SCRIPT_DIR/stacks/${stack}.test.sh"
    
    if [[ ! -f "$test_file" ]]; then
        echo "⚠️  Test file not found: $test_file"
        return 0
    fi
    
    source "$test_file"
}

main() {
    local stack_name=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --stack) stack_name="$2"; shift 2 ;;
            --all) run_all=true; shift ;;
            --help) show_help; exit 0 ;;
            *) echo "Unknown option: $1"; show_help; exit 1 ;;
        esac
    done
    
    if [[ -n "$stack_name" ]]; then
        run_stack_tests "$stack_name"
    else
        echo "Usage: $0 --stack <name> | --all | --help"
        exit 1
    fi
}

main "$@"
