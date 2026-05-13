# Codex Security Review - Issue #504 Authentik SSO

Scan target: staged diff for the Authentik SSO implementation.

Reviewer: GPT-5 Codex with Codex Security workflow.

Date: 2026-05-13

## Threat Model

This repository deploys a Docker-based homelab stack behind Traefik. The most
important assets are identity/session integrity, OAuth client secrets, service
admin access, local Docker control, and data reachable by stack services.

Primary trust boundaries:

- Public HTTPS traffic enters through Traefik.
- Authentik is the identity provider for protected services.
- Setup scripts run with operator privileges on the Docker host.
- `.env` files are local operator-controlled secret stores and are ignored by
  git.
- Docker containers and mounted volumes are trusted deployment components, not
  attacker input.

Security invariants for this patch:

- No real secrets are committed.
- Generated OAuth secrets are written only to ignored local `.env` files.
- OIDC redirect URIs are service-specific and not wildcarded.
- Authentik providers are confidential clients.
- The setup flow is idempotent and does not execute attacker-controlled data.
- Traefik ForwardAuth has one clear middleware definition.

## Finding Discovery

Reviewed changed surfaces:

- `scripts/authentik-setup.sh`
- `scripts/setup-authentik.sh`
- `scripts/gitea-oidc-setup.sh`
- `scripts/nextcloud-oidc-setup.sh`
- `scripts/test-authentik-sso.sh`
- `stacks/sso/docker-compose.yml`
- `stacks/ai/docker-compose.yml`
- `stacks/monitoring/docker-compose.yml`
- `config/grafana/grafana.ini`
- `config/traefik/dynamic/middlewares.yml`
- all changed `.env.example` files

Candidate checks:

1. Secret disclosure through tracked files.
   - Result: suppressed. Tracked files contain placeholders only. `.env`,
     `*.env`, backups, logs, certs, and generated Traefik dynamic files are
     ignored by `.gitignore`.

2. OAuth redirect broadening.
   - Result: suppressed. Providers are created with exact redirect URIs for
     Grafana, Gitea, Nextcloud, Outline, Open WebUI, and Portainer. No wildcard
     redirect URI is introduced.

3. Local login bypass for Open WebUI.
   - Result: fixed during review. `ENABLE_LOGIN_FORM` is set to `false` so
     Authentik remains the intended login path.

4. Authentik token leakage in scripts or logs.
   - Result: suppressed. The token is used only as an Authorization header and
     is not printed by the scripts.

5. Shell command injection in setup scripts.
   - Result: suppressed. Inputs come from operator-controlled `.env` files,
     variables are quoted, no `eval` is used, and service CLIs are invoked with
     fixed command structures.

6. Conflicting ForwardAuth middleware.
   - Result: suppressed. The duplicate `config/traefik/dynamic/authentik.yml`
     definition is removed; the stack keeps one `authentik` middleware in
     `config/traefik/dynamic/middlewares.yml`.

7. Docker socket exposure.
   - Result: not introduced by this patch. The Authentik worker's Docker socket
     mount is part of the existing outpost pattern for the stack and is not
     expanded.

No reportable security finding survived discovery.

## Validation

Validation method: static diff review plus realistic Docker runtime execution
on a Linux VM.

Executed checks:

- `git diff --cached --check`
- `bash -n` for all changed shell scripts
- `docker compose config` for `base`, `sso`, `monitoring`, `productivity`,
  `storage`, and `ai`
- `scripts/authentik-setup.sh --dry-run`
- Authentik stack startup with:
  - `ghcr.io/goauthentik/server:2024.8.3`
  - `postgres:16.4-alpine`
  - `redis:7.4.0-alpine`
- real Authentik API setup for three groups and six OAuth2 providers/apps
- live OIDC discovery checks for all six provider slugs
- live Authentik API checks for expected groups/providers

Runtime result:

```text
homelab-admins group OK
homelab-users group OK
media-users group OK
Grafana OAuth2 provider OK
Gitea OAuth2 provider OK
Nextcloud OAuth2 provider OK
Outline OAuth2 provider OK
Open WebUI OAuth2 provider OK
Portainer OAuth2 provider OK
Authentik SSO checks passed
```

## Attack Path Analysis

No surviving candidate has an attacker-controlled source, broken control, and
security-relevant sink.

The remaining privileged actions are operator-run setup operations. The local
`.env` files and Docker access required to run those scripts are already
administrator-level deployment privileges, so they do not form a new
cross-boundary attacker path.

## Final Result

No reportable security findings in the staged Authentik SSO implementation.

The only actionable hardening item found during review was fixed:

- Open WebUI local login is disabled with `ENABLE_LOGIN_FORM=false`.
