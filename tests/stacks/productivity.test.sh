test_gitea_running() {
  assert_container_running "gitea"
  assert_container_healthy "gitea"
}

test_gitea_runner_running() {
  assert_container_running "gitea-runner"
}

test_vaultwarden_running() {
  assert_container_running "vaultwarden"
  assert_container_healthy "vaultwarden"
}

test_outline_running() {
  assert_container_running "outline"
  assert_container_healthy "outline"
}

test_bookstack_running() {
  assert_container_running "bookstack"
  assert_container_healthy "bookstack"
}

test_stirling_pdf_running() {
  assert_container_running "stirling-pdf"
}

test_excalidraw_running() {
  assert_container_running "excalidraw"
}

