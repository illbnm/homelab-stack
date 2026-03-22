#!/bin/bash

test_gotify_running() {
  assert_container_running "gotify"
}