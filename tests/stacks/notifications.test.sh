test_ntfy_running() {
  assert_container_running "ntfy"
  assert_container_healthy "ntfy"
}

test_apprise_running() {
  assert_container_running "apprise"
  assert_container_healthy "apprise"
}

