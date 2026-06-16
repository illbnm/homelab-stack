#!/bin/bash

test_postgresql_running() {
  assert_container_running "postgresql"
}