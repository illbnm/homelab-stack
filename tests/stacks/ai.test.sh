#!/bin/bash

source ../lib/assert.sh

test_ollama_running() {
  assert_container_running "ollama"
  assert_http_200 "http://localhost:11434/api/version"
}

test_openwebui_running() {
  assert_container_running "openwebui"
}