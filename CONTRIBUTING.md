# Contributing to Homelab Stack

## Quality & Security Standards

1. **No `:latest` Image Tags**: Every Docker image in `stacks/*/docker-compose.yml` MUST be pinned to an explicit semantic version tag.
2. **CN Registry Mirror Comments**: Include `# 国内镜像替换: ...` above each `image:` declaration.
3. **Healthchecks & Resource Limits**: Every service MUST define both `healthcheck` and `deploy.resources.limits`.
4. **No Hardcoded Passwords**: Required secrets must use `${VAR:?error message}` syntax and be documented in `.env.example`.

## Running the Automated Test Suite

```bash
# Run all static & assertion checks across all 10 stacks + E2E
bash tests/run-tests.sh --all --static --json report.json

# Run tests for a single stack
bash tests/run-tests.sh --stack sso
```
