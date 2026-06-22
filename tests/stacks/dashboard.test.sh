test_homarr_running() {
  assert_container_running "homarr"
  assert_container_healthy "homarr"
}

test_homepage_running() {
  assert_container_running "homepage"
  assert_container_healthy "homepage"
}

