# Contributing

## Stack changes

Every new stack PR must include a matching `tests/stacks/<stack>.test.sh` file and must be runnable through:

```bash
./tests/run-tests.sh --stack <stack>
```

The test file should cover compose validation, pinned image tags, container running state, health checks where available, key HTTP endpoints or service readiness checks, and any stack-specific configuration requirements.

## Full validation

Before opening a PR, run:

```bash
shellcheck scripts/*.sh tests/run-tests.sh tests/lib/*.sh tests/stacks/*.test.sh tests/e2e/*.test.sh
./tests/run-tests.sh --stack base
```

When all stacks are running, run:

```bash
./tests/run-tests.sh --all
```
