# Testing Stack — Integration Tests

**Bounty:** #14 — Testing & Integration ($280 USDT)

## Structure

```
tests/
├── run-tests.sh              # Test runner (--stack <name> or --all)
├── lib/
│   └── assert.sh             # Assertion library
```

## Quick Start

```bash
# Test all stacks
./tests/run-tests.sh all

# Test specific stack
./tests/run-tests.sh storage
```

## Assertions Available

- `assert_file_exists` — Check file presence
- `assert_container_running` — Check container is Up
- `assert_http` — HTTP endpoint check
- `assert_eq` — Value comparison
