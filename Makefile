# DexDictate developer tasks.
# `make check` is the local quality gate: lint + build + tests.

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Debug build
	swift build

.PHONY: build-release
build-release: ## Compile in release configuration (no signing/packaging)
	swift build -c release

.PHONY: test
test: ## Run the test suite
	swift test

# NOTE: .swiftlint-baseline.json is keyed by absolute file path (a SwiftLint
# limitation, see docs/SWIFTLINT_DEBT.md), so it only suppresses known debt
# when swiftlint runs from CI's checkout path. `make lint` run from an
# arbitrary local clone will show the full historical debt; that's expected.
.PHONY: lint
lint: ## Run SwiftLint in strict mode against the committed baseline (fails if swiftlint is missing)
	@if ! command -v swiftlint >/dev/null 2>&1; then \
		echo "error: swiftlint is not installed. Install with: brew install swiftlint"; \
		echo "       (expected version: $$(cat .swiftlint-version 2>/dev/null || echo unknown))"; \
		exit 1; \
	fi
	@installed="$$(swiftlint version)"; expected="$$(cat .swiftlint-version 2>/dev/null || echo unknown)"; \
		if [ "$$installed" != "$$expected" ]; then \
			echo "warning: installed swiftlint $$installed differs from pinned $$expected (see docs/SWIFTLINT_DEBT.md)"; \
		fi
	swiftlint lint --strict --baseline .swiftlint-baseline.json

.PHONY: lint-gate-test
lint-gate-test: ## Prove the SwiftLint baseline gate rejects new violations
	bash scripts/test_swiftlint_gate.sh

.PHONY: lint-debt
lint-debt: ## Show the full baselined SwiftLint debt (existing violations, suppressed by design)
	@if ! command -v swiftlint >/dev/null 2>&1; then \
		echo "error: swiftlint is not installed. Install with: brew install swiftlint"; \
		exit 1; \
	fi
	swiftlint baseline report .swiftlint-baseline.json --reporter summary

.PHONY: check
check: lint build test ## Local quality gate: lint + build + tests
	@echo "check: OK"

.PHONY: coverage
coverage: ## Run tests with code coverage and print where the data is
	swift test --enable-code-coverage
	@echo "Coverage data (JSON): $$(swift test --show-codecov-path 2>/dev/null)"

.PHONY: release
release: ## Build, sign, validate and package a release (requires local signing identity)
	./build.sh --release

.PHONY: validate
validate: ## Validate the most recently assembled app bundle
	./scripts/validate_release.sh .build/DexDictate.app

.PHONY: clean
clean: ## Remove build artifacts
	swift package clean
	rm -rf .build/DexDictate.app
