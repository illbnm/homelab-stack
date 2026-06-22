test_adguardhome_running() {
  assert_container_running "adguardhome"
  assert_container_healthy "adguardhome"
}

test_nginx_proxy_manager_running() {
  assert_container_running "nginx-proxy-manager"
  assert_container_healthy "nginx-proxy-manager"
}

