# Productivity stack

Gitea (`git`), Vaultwarden (`vault`), Outline (`docs`), BookStack (`wiki`),
Stirling PDF (`pdf`), and Excalidraw (`draw`) use HTTPS subdomains of `DOMAIN`.
BookStack is retained from the existing stack. Gitea stays at the repository's
1.22.3 patch version; the other requested images retain the issue's versions.
Excalidraw is the standalone browser whiteboard; collaboration is not configured.

## Setup

1. Start the base, databases, SSO, and storage stacks first. Configure DNS for all
   subdomains, including `s3`, and set the ACME email in `config/traefik/traefik.yml`.
   Traefik needs reachable ports 80/443 to issue trusted certificates.
2. Copy this directory's `.env.example` to `.env` and fill it. Database passwords
   must match `stacks/databases/.env`; Redis must match too. Use hex database
   passwords to avoid URI encoding issues. Outline secrets need 32 random bytes
   encoded as 64 hex characters. Use a strong Vaultwarden admin token; if using
   an Argon2 hash, single-quote it in `.env` so Compose preserves dollar signs.
3. In MinIO, create the private `OUTLINE_S3_BUCKET` bucket and a dedicated service
   account with read/write/delete/list access restricted to that bucket. Put its
   credentials in the Outline S3 variables. Ensure `https://s3.DOMAIN` is reachable
   from both browsers and Outline and has a trusted certificate. Set bucket CORS
   to allow `https://docs.DOMAIN` and required upload/download methods and headers.
4. Create Authentik confidential OIDC providers with `openid`, `profile`, and
   `email` scopes. Gitea's slug is `gitea`, callback
   `https://git.DOMAIN/user/oauth2/Authentik/callback`; Outline's slug is `outline`,
   callback `https://docs.DOMAIN/auth/oidc.callback`. The existing
   `scripts/setup-authentik.sh` creates providers and writes to the root `.env`;
   copy the matching client values into this stack's `.env` securely.
5. From this directory run `docker compose up -d`. Once Gitea is healthy, run
   `docker compose exec --user git gitea sh /configure-gitea-oidc.sh` once to create
   its authentication source. For existing sources, update through Gitea's admin
   UI instead of rerunning the add command. Create the initial Gitea administrator
   with `gitea admin user create` inside the container as user `git`, using
   `/data/gitea/conf/app.ini`. Pre-create regular accounts as administrator, then
   link Authentik from each account's settings; automatic registration is disabled.
6. Configure an authenticated SMTP relay with a permitted sender. Vaultwarden
   public registration, organization invitations, and emergency access invitations
   are disabled; the protected `/admin` UI can invite users. Existing settings in
   Vaultwarden's `/data/config.json` override environment values: review them when
   upgrading an existing installation.

PostgreSQL initialization only runs for an empty database volume. Existing
installations must reconcile service roles/passwords explicitly; do not delete
volumes to rerun initialization. Existing Outline uploads must be backed up and
migrated from the retained `outline-data` volume to MinIO before switching storage.

## Optional Actions runner

Obtain a registration token from Gitea's administrator Actions settings, fill
`GITEA_RUNNER_REGISTRATION_TOKEN`, then run
`docker compose --profile actions up -d gitea-runner`. Enable Actions for the test
repository. Registration state persists in `gitea-runner-data`. The runner mounts
the host Docker socket and workflows can control the host; enable it only for
trusted repositories. Job containers must resolve and reach `https://git.DOMAIN`.

## Verification

Offline: install PyYAML and run `python3 -m unittest discover -s tests` at the repo
root. These checks validate configuration contracts, not deployed functionality.
With filled configuration, run `docker compose config --quiet` in this directory.

On a deployed test host, verify certificates without disabling TLS validation;
log in through Authentik to a pre-created Gitea account, push and clone a repository
via HTTPS with a Gitea personal access token, and run a simple Actions job. Connect
a Bitwarden extension to `https://vault.DOMAIN`, invite a test user from `/admin`,
and verify email delivery and sync. Log in to Outline, edit a document, upload and
retrieve an attachment, and confirm the object is in MinIO. Open the Stirling PDF
pages and process a sample PDF; draw and export from Excalidraw. Live acceptance
requires these checks and cannot be established by static tests.

Configuration references: [Gitea 1.22 CLI](https://docs.gitea.com/1.22/administration/command-line/),
[Vaultwarden 1.32 environment template](https://github.com/dani-garcia/vaultwarden/blob/1.32.0/.env.template),
and [Outline S3 configuration](https://github.com/outline/outline/blob/main/.env.sample).
