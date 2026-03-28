.PHONY: test test-compose test-env test-network test-backup test-notifications test-all lint

test: test-all

test-all:
	@echo "Running all tests..."
	@bash tests/test-compose.sh
	@bash tests/test-env.sh
	@bash tests/test-network.sh
	@bash tests/test-backup.sh
	@bash tests/test-notifications.sh

test-compose:
	bash tests/test-compose.sh

test-env:
	bash tests/test-env.sh

test-network:
	bash tests/test-network.sh

test-backup:
	bash tests/test-backup.sh

test-notifications:
	bash tests/test-notifications.sh

lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo "Install shellcheck: apt install shellcheck"; exit 1; }
	@find scripts/ tests/ -name '*.sh' -exec shellcheck {} +
