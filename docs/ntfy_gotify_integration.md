# Ntfy and Gotify Integration for Notifications

This guide provides instructions on how to integrate ntfy and Gotify notification services into your HomeLab stack.

## Prerequisites
- HomeLab stack running on your server.
- Docker and Docker Compose installed.

## Installation
1. Clone the repository and navigate to the `src/notifications/` directory.
2. Run the following script to install and configure ntfy and Gotify:

   ```bash
   bash ntfy_gotify_integration.sh
   ```

3. The script will install both ntfy and Gotify and start the services.

## Configuration
1. Edit the ntfy configuration file located at `/etc/ntfy/config.yaml` to suit your needs.
2. Edit the Gotify configuration file located at `/etc/gotify/config.yaml`.

## Test Notification
You can send a test notification from either ntfy or Gotify to ensure the setup is complete.

For ntfy:
```bash
ntfy send "Test message from ntfy!"
```
For Gotify:
```bash
gotify send "Test message from Gotify!"
```
