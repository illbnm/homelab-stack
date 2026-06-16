#!/bin/bash

test_ollama_running() {
  assert_container_running "ollama"
  assert_http_200 "http://localhost:11434/api/version"
}

test_open_webui_running() {
  assert_container_running "open-webui"
}