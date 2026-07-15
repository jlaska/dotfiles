PACKAGES := $(shell find . -mindepth 1 -maxdepth 1 -type d -not -name '.*' | sed 's|./||')

.DEFAULT_GOAL := help

.PHONY: help setup lint pre-commit check

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Install prerequisites and prepare git hooks
	@command -v brew >/dev/null || { echo "Error: Homebrew not found"; exit 1; }
	@command -v stow >/dev/null || brew install stow
	@command -v pre-commit >/dev/null || brew install pre-commit
	pre-commit install
	@test -f .secrets.baseline || detect-secrets scan > .secrets.baseline
	@for pkg in $(PACKAGES); do \
		stow --no-folding -t "$$HOME" "$$pkg" && echo "stowed: $$pkg"; \
	done

lint: ## Run style and format linters
	pre-commit run trailing-whitespace --all-files
	pre-commit run end-of-file-fixer --all-files
	pre-commit run check-json --all-files
	pre-commit run markdownlint --all-files

pre-commit: ## Run all pre-commit hooks
	pre-commit run --all-files

check: ## Verify all stow symlinks are intact (dry-run restow)
	@ok=true; \
	for pkg in $(PACKAGES); do \
		output=$$(stow --simulate --restow --no-folding -t "$$HOME" "$$pkg" 2>&1); \
		if echo "$$output" | grep -q "cannot stow\|WARNING!"; then \
			echo "CONFLICT  $$pkg"; echo "$$output"; ok=false; \
		else \
			echo "OK        $$pkg"; \
		fi; \
	done; \
	$$ok
