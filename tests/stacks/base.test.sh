#!/bin/bash

source ../lib/assert.sh

test_traefik_running() {
  assert_container_running "traefik"
  assert_container_healthy "traefik"
}

test_portainer_running() {
  assert_container_running "portainer"
  assert_http_200 "http://localhost:9000"
}

test_watchtower_running() {
  assert_container_running "watchtower"
}