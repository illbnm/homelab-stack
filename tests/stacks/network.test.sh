test_adguardhome_running() {
  assert_container_running "adguardhome"
  assert_container_healthy "adguardhome"
}

test_unbound_running() {
  assert_container_running "unbound"
  assert_container_healthy "unbound"
}

test_wg_easy_running() {
  assert_container_running "wg-easy"
  assert_container_healthy "wg-easy"
}

test_cloudflare_ddns_running() {
  assert_container_running "cloudflare-ddns"
}

test_nginx_proxy_manager_running() {
  assert_container_running "nginx-proxy-manager"
  assert_container_healthy "nginx-proxy-manager"
}

