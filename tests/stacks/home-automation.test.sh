#!/bin/bash

test_home_assistant_running() {
  assert_container_running "home-assistant"
}