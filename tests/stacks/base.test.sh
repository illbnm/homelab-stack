test_traefik_running() { assert_container_running "traefik"; }
test_traefik_api() { assert_http_200 "http://localhost:8080/api/version" 10; }
test_portainer_running() { assert_container_running "portainer"; }
test_portainer_api() { assert_http_200 "http://localhost:9000/api/status" 10; }
test_watchtower_running() { assert_container_running "watchtower"; }
test_compose_syntax() { for f in $(find "$ROOT_DIR/stacks" -name 'docker-compose.yml'); do assert_exit_code "$(docker compose -f "$f" config --quiet 2>&1; echo $?)" "compose config: $f"; done }
test_no_latest_tags() { assert_no_latest_images "$ROOT_DIR/stacks"; }
