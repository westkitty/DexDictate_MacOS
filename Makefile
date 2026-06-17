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

.PHONY: lint
lint: ## Run SwiftLint in strict mode (no-op if not installed)
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint --strict; \
	else \
		echo "swiftlint not installed; skipping (brew install swiftlint)"; \
	fi

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
