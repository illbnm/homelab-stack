test_compose_syntax() {
  for c in $(find stacks -name 'docker-compose.yml'); do
    docker compose -f "$c" config --quiet 2>&1
    local code=$?
    assert_eq "$code" "0" "$c compose config failed"
  done
}

test_no_latest_tags() {
  assert_no_latest_images "stacks/"
}

test_traefik_running() {
  assert_container_running "traefik"
  assert_container_healthy "traefik"
}

test_portainer_running() {
  assert_container_running "portainer"
  assert_container_healthy "portainer"
}

test_watchtower_running() {
  assert_container_running "watchtower"
  assert_container_healthy "watchtower"
}

