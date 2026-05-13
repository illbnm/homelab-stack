# Claude Opus Review Evidence - Issue #504

Command:

```text
claude -p --model claude-opus-4-6 --max-budget-usd 1.50 --permission-mode dontAsk --allowedTools "Bash(git *)" "Bash(rg *)" "Read" --output-format json
```

Representative result excerpt:

```text
model_used: claude-opus-4-6
verdict: PASS
blocking_issues: None.
```

Non-blocking notes from the review:

1. Grafana OAuth configuration existed in both `config/grafana/grafana.ini`
   and `stacks/monitoring/docker-compose.yml`.
2. Redis healthcheck uses the normal Redis password-bearing healthcheck pattern.
3. Grafana scopes should explicitly include `groups`.
4. `AUTHENTIK_BOOTSTRAP_TOKEN` remains in container environment after bootstrap.
5. Some existing storage placeholders use `CHANGE_ME`.

Actions taken after review:

- Removed duplicate Grafana OAuth `GF_AUTH_GENERIC_OAUTH_*` environment
  settings from `stacks/monitoring/docker-compose.yml`.
- Kept `config/grafana/grafana.ini` as the single Grafana OAuth source of
  truth required by issue #504.
- Added `groups` to the Grafana OAuth scopes.

Remaining notes are accepted deployment tradeoffs or pre-existing placeholder
style, not blockers for the SSO implementation.
