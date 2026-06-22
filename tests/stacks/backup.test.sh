test_duplicati_running() {
  assert_container_running "duplicati"
}

test_rest_server_running() {
  assert_container_running "restic-server"
}

