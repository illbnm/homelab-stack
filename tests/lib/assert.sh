assert_fail() {
  echo "$1" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local msg="$3"
  if [ "$actual" != "$expected" ]; then
    assert_fail "${msg:-Expected '$expected', Got '$actual'}"
  fi
}

assert_not_empty() {
  local value="$1"
  local msg="$2"
  if [ -z "$value" ]; then
    assert_fail "${msg:-Expected non-empty value}"
  fi
}

assert_exit_code() {
  local expected="$1"
  local msg="$2"
  local actual=$?
  if [ "$actual" != "$expected" ]; then
    assert_fail "${msg:-Expected exit code '$expected', Got '$actual'}"
  fi
}

assert_container_running() {
  local name="$1"
  local state
  state=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || true)
  if [ "$state" != "running" ]; then
    assert_fail "Container $name is not running (state: $state)"
  fi
}

assert_container_healthy() {
  local name="$1"
  local timeout=60
  local start
  start=$(date +%s)
  while true; do
    local state
    state=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || true)
    if [ "$state" == "healthy" ]; then
      return 0
    elif [ "$state" == "none" ]; then
      return 0
    fi
    local now
    now=$(date +%s)
    if [ $((now - start)) -ge $timeout ]; then
      assert_fail "Container $name failed to become healthy within ${timeout}s (state: $state)"
    fi
    sleep 2
  done
}

assert_http_200() {
  local url="$1"
  local timeout="${2:-30}"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" || true)
  if [ "$status" != "200" ]; then
    assert_fail "Expected HTTP 200 for $url, Got: $status"
  fi
}

assert_http_response() {
  local url="$1"
  local pattern="$2"
  local content
  content=$(curl -s "$url" || true)
  if ! echo "$content" | grep -q "$pattern"; then
    assert_fail "URL $url response did not match pattern '$pattern'"
  fi
}

assert_json_value() {
  local json="$1"
  local jq_path="$2"
  local expected="$3"
  local actual
  actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || true)
  if [ "$actual" != "$expected" ]; then
    assert_fail "Expected JSON value '$expected' at $jq_path, Got: '$actual'"
  fi
}

assert_json_key_exists() {
  local json="$1"
  local jq_path="$2"
  local actual
  actual=$(echo "$json" | jq -e "$jq_path" >/dev/null 2>&1; echo $?)
  if [ "$actual" != "0" ]; then
    assert_fail "Expected JSON key $jq_path to exist"
  fi
}

assert_no_errors() {
  local json="$1"
  local errors
  errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null || echo "invalid_json")
  if [ "$errors" != "" ] && [ "$errors" != "null" ]; then
    assert_fail "Expected no errors in JSON, but found: $errors"
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -q "$pattern" "$file" 2>/dev/null; then
    assert_fail "File $file does not contain pattern '$pattern'"
  fi
}

assert_no_latest_images() {
  local dir="$1"
  local count
  count=$(grep -r -E 'image:.*:latest' "$dir" | wc -l || true)
  # Trim spaces
  count=$(echo "$count" | xargs)
  if [ "$count" -ne 0 ]; then
    assert_fail "Found :latest image tags in $dir"
  fi
}

assert_no_gcr_images() {
  local dir="$1"
  local count
  count=$(grep -r -E 'image:.*gcr\.io' "$dir" | wc -l || true)
  count=$(echo "$count" | xargs)
  if [ "$count" -ne 0 ]; then
    assert_fail "Found gcr.io images in $dir"
  fi
}
