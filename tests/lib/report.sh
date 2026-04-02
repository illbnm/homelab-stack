#!/bin/bash

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

report_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ $1 -eq 0 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

print_summary() {
    echo ""
    echo "=== Test Summary ==="
    echo "Tests run:    $TESTS_RUN"
    echo "Passed:       $TESTS_PASSED"
    echo "Failed:       $TESTS_FAILED"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo "Status: ✅ All tests passed"
        return 0
    else
        echo "Status: ❌ Some tests failed"
        return 1
    fi
}
