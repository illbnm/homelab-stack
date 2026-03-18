# AI stack tests

CURRENT_TEST="ollama_running"
assert_container_running "ollama"

CURRENT_TEST="ollama_healthy"
assert_container_healthy "ollama"

CURRENT_TEST="ollama_api"
assert_http_200 "http://localhost:11434/api/tags"

CURRENT_TEST="open_webui_running"
assert_container_running "open-webui"

CURRENT_TEST="open_webui_healthy"
assert_container_healthy "open-webui"

CURRENT_TEST="open_webui_http"
assert_http_200 "http://localhost:8080/health"

CURRENT_TEST="stable_diffusion_running"
assert_container_running "stable-diffusion"

CURRENT_TEST="perplexica_running"
assert_container_running "perplexica"

CURRENT_TEST="perplexica_healthy"
assert_container_healthy "perplexica"
