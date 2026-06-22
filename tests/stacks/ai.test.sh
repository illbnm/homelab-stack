test_ollama_running() {
  assert_container_running "ollama"
  assert_container_healthy "ollama"
}

test_open_webui_running() {
  assert_container_running "open-webui"
  assert_container_healthy "open-webui"
}

test_stable_diffusion_running() {
  assert_container_running "stable-diffusion"
  assert_container_healthy "stable-diffusion"
}

