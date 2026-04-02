#!/usr/bin/env bash
# 测试报告生成器 - HomeLab Stack Integration Tests

set -euo pipefail

REPORT_DIR="tests/results"
REPORT_FILE="$REPORT_DIR/report.json"

# 初始化报告
init_report() {
    mkdir -p "$REPORT_DIR"

    cat > "$REPORT_FILE" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "tests": [],
  "summary": {
    "total": 0,
    "passed": 0,
    "failed": 0,
    "skipped": 0
  }
}
EOF
}

# 添加测试结果
add_test_result() {
    local test_name="$1"
    local status="$2"  # pass, fail, skip
    local duration="$3"
    local message="${4:-}"

    local test_entry
    test_entry=$(cat <<EOF
{
  "name": "$test_name",
  "status": "$status",
  "duration": "$duration",
  "message": "$message",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
)

    # 使用jq添加测试结果
    local temp_file
    temp_file=$(mktemp)
    jq ".tests += [$test_entry]" "$REPORT_FILE" > "$temp_file"
    mv "$temp_file" "$REPORT_FILE"
}

# 更新摘要
update_summary() {
    local passed="$1"
    local failed="$2"
    local skipped="$3"

    local temp_file
    temp_file=$(mktemp)

    jq ".summary = {
        \"total\": $((passed + failed + skipped)),
        \"passed\": $passed,
        \"failed\": $failed,
        \"skipped\": $skipped
    }" "$REPORT_FILE" > "$temp_file"

    mv "$temp_file" "$REPORT_FILE"
}

# 打印终端报告
print_terminal_report() {
    local passed="$1"
    local failed="$2"
    local skipped="$3"
    local duration="$4"

    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║   HomeLab Stack — Integration Tests  ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    if [[ "$failed" -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
    else
        echo -e "${RED}Some tests failed!${NC}"
    fi

    echo ""
    echo "──────────────────────────────────────"
    echo "Results: $passed passed, $failed failed, $skipped skipped"
    echo "Duration: ${duration}s"
    echo "──────────────────────────────────────"

    if [[ -f "$REPORT_FILE" ]]; then
        echo "JSON report: $REPORT_FILE"
    fi
}

# 生成HTML报告
generate_html_report() {
    local html_file="$REPORT_DIR/report.html"

    cat > "$html_file" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HomeLab Stack - Integration Test Report</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 15px;
            margin-bottom: 20px;
        }
        .summary-card {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 {
            margin: 0;
            color: #666;
            font-size: 14px;
        }
        .summary-card .number {
            font-size: 32px;
            font-weight: bold;
            margin-top: 10px;
        }
        .passed { color: #10b981; }
        .failed { color: #ef4444; }
        .skipped { color: #f59e0b; }
        .test-list {
            background: white;
            border-radius: 10px;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .test-item {
            padding: 10px;
            border-bottom: 1px solid #eee;
        }
        .test-item:last-child {
            border-bottom: none;
        }
        .status-badge {
            padding: 4px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
            text-transform: uppercase;
        }
        .status-pass { background: #d1fae5; color: #065f46; }
        .status-fail { background: #fee2e2; color: #991b1b; }
        .status-skip { background: #fef3c7; color: #92400e; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 HomeLab Stack - Integration Test Report</h1>
        <p>Generated at: <span id="timestamp"></span></p>
    </div>
    <div class="summary">
        <div class="summary-card">
            <h3>Total Tests</h3>
            <div class="number" id="total">0</div>
        </div>
        <div class="summary-card">
            <h3>Passed</h3>
            <div class="number passed" id="passed">0</div>
        </div>
        <div class="summary-card">
            <h3>Failed</h3>
            <div class="number failed" id="failed">0</div>
        </div>
        <div class="summary-card">
            <h3>Skipped</h3>
            <div class="number skipped" id="skipped">0</div>
        </div>
    </div>
    <div class="test-list">
        <h2>Test Results</h2>
        <div id="tests"></div>
    </div>
    <script>
        fetch('report.json')
            .then(response => response.json())
            .then(data => {
                document.getElementById('timestamp').textContent = data.timestamp;
                document.getElementById('total').textContent = data.summary.total;
                document.getElementById('passed').textContent = data.summary.passed;
                document.getElementById('failed').textContent = data.summary.failed;
                document.getElementById('skipped').textContent = data.summary.skipped;

                const testsDiv = document.getElementById('tests');
                data.tests.forEach(test => {
                    const testDiv = document.createElement('div');
                    testDiv.className = 'test-item';
                    testDiv.innerHTML = `
                        <span class="status-badge status-${test.status}">${test.status}</span>
                        <strong>${test.name}</strong>
                        <span style="float: right; color: #666;">${test.duration}</span>
                    `;
                    testsDiv.appendChild(testDiv);
                });
            });
    </script>
</body>
</html>
EOF

    echo "HTML report generated: $html_file"
}
