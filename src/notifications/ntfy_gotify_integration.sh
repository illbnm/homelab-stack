#!/bin/bash
# Script to integrate ntfy and Gotify into HomeLab stack for notifications

# Check if ntfy is already installed
if ! command -v ntfy &> /dev/null
then
  echo "ntfy is not installed. Installing..."
  curl -s https://ntfy.sh/install.sh | bash
else
  echo "ntfy is already installed."
fi

# Check if Gotify is already installed
if ! command -v gotify &> /dev/null
then
  echo "Gotify is not installed. Installing..."
  curl -s https://gotify.net/download | bash
else
  echo "Gotify is already installed."
fi

# Start ntfy service
echo "Starting ntfy service..."
ntfy start

# Start Gotify service
echo "Starting Gotify service..."
gotify start

# Provide instructions for configuration
echo "Please configure ntfy and Gotify by editing the respective configuration files located at /etc/ntfy/config.yaml and /etc/gotify/config.yaml"
