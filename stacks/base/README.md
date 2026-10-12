# Base Infrastructure Stack

This stack provides the foundational services for your homelab: Traefik (reverse proxy with automatic HTTPS), Portainer (Docker management UI), Watchtower (container auto-updater), and a Docker Socket Proxy (for security).

## Services

*   **Traefik**: Handles all incoming traffic, routes it to the correct services, and automatically manages Let's Encrypt certificates.
*   **Portainer CE**: A web-based UI for managing your Docker containers, images, volumes, and networks.
*   **Watchtower**: Automatically checks for new Docker image updates and restarts containers with the new images.
*   **Docker Socket Proxy**: Provides a secure, restricted interface to the Docker daemon, preventing services from having full root access.

## File Structure

