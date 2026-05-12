test_gitea_running() { assert_container_running "gitea"; }
test_gitea_api() { assert_http_200 "http://localhost:3000/api/v1/version" 15; }
test_vaultwarden_running() { assert_container_running "vaultwarden"; }
test_vaultwarden_health() { assert_http_200 "http://localhost:80/alive" 10; }
test_outline_running() { assert_container_running "outline"; }
test_outline_health() { assert_http_200 "http://localhost:3000/_health" 15; }
test_stirling_pdf_running() { assert_container_running "stirling-pdf"; }
test_stirling_pdf_http() { assert_http_200 "http://localhost:8080" 15; }
test_excalidraw_running() { assert_container_running "excalidraw"; }
