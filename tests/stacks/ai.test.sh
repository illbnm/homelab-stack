#!/usr/bin/env bash
set -euo pipefail

test_ollama_running() { assert_container_healthy ollama; }
test_open_webui_running() { assert_container_healthy open-webui; }
test_stable_diffusion_running() { assert_container_healthy stable-diffusion; }
