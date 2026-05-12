test_adguard_running() { assert_container_running "adguard"; }
test_adguard_api() { assert_http_200 "http://localhost:80/control/status" 10; }
test_wireguard_running() { assert_container_running "wireguard"; }
test_ddns_running() { assert_container_running "cloudflare-ddns"; }
test_dns_resolution() { assert_http_200 "http://localhost:80/control/status" 10; }
