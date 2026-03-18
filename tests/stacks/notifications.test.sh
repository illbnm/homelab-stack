#!/bin/bash

test_gotify_running() {
  assert_container_running "gotify"
  assert_http_200 "http://localhost:8080/version"
}

test_ntfy_running() {
  assert_container_running "ntfy"
}