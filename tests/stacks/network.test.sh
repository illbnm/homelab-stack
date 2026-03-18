# Network stack tests

CURRENT_TEST="adguard_running"
assert_container_running "adguard"

CURRENT_TEST="adguard_healthy"
assert_container_healthy "adguard"

CURRENT_TEST="adguard_http"
assert_http_200 "http://localhost:3000/"

CURRENT_TEST="adguard_dns"
local dns_result=$(dig @localhost example.com +short 2>/dev/null || echo "")
assert_not_empty "$dns_result" "AdGuard DNS resolves"

CURRENT_TEST="unbound_running"
assert_container_running "unbound"

CURRENT_TEST="unbound_healthy"
assert_container_healthy "unbound"

CURRENT_TEST="wireguard_running"
assert_container_running "wireguard"

CURRENT_TEST="wireguard_healthy"
assert_container_healthy "wireguard"

CURRENT_TEST="wireguard_http"
assert_http_200 "http://localhost:51821/"

CURRENT_TEST="cloudflare_ddns_running"
assert_container_running "cloudflare-ddns"
