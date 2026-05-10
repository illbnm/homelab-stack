#!/usr/bin/env bash
# Storage Stack — Nextcloud, MinIO, FileBrowser, Syncthing tests
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$(dirname "$SCRIPT_DIR")/lib/assert.sh"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

describe "Storage"

it "nextcloud container running"; assert_container_running "nextcloud"
it "nextcloud-nginx running"; assert_container_running "nextcloud-nginx"
it "nextcloud-nginx healthy"; assert_container_healthy "nextcloud-nginx"

it "minio running"; assert_container_running "minio"
it "minio healthy"; assert_container_healthy "minio"
it "minio health endpoint"; assert_http_200 "http://minio:9000/minio/health/live"

it "filebrowser running"; assert_container_running "filebrowser"
it "filebrowser health endpoint"; assert_http_200 "http://filebrowser:80/health"

it "syncthing running"; assert_container_running "syncthing"
it "syncthing health endpoint"; assert_http_200 "http://syncthing:8384/rest/noauth/health"

it "minio API accessible"; assert_http_200 "http://minio:9000/minio/health/ready"
it "nextcloud nginx config valid"; assert_file_exists "${ROOT_DIR}/config/nextcloud/nginx.conf"