#!/usr/bin/env bash

run_storage_tests() {
  CURRENT_SUITE="storage"
  assert_stack_static_checks storage
  assert_compose_services_declared storage nextcloud minio filebrowser
  assert_stack_containers_running nextcloud minio filebrowser
  assert_stack_containers_healthy nextcloud minio filebrowser
  assert_container_on_network nextcloud proxy "Nextcloud is attached to proxy network"
  assert_container_on_network minio proxy "MinIO is attached to proxy network"
}
