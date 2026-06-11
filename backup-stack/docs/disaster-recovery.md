# Disaster Recovery Plan
## Recovery Time Objective (RTO): 4 hours
## Recovery Steps
1. Install Docker and clone the homelab-stack repository.
2. Start the Base Infrastructure stack (Traefik, Portainer).
3. Start the Databases stack (PostgreSQL, Redis).
4. Start the SSO stack (Authentik).
5. Start all other stacks.
6. Run `backup.sh --restore <latest-backup-id>` for each volume.
7. Verify services are accessible and data is intact.
