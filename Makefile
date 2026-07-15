PACKAGES           := $(shell find . -mindepth 1 -maxdepth 1 -type d -not -name '.*' | sed 's|./||')
OMZ_PLUGINS        := $(HOME)/.oh-my-zsh/custom/plugins
OMZ_PLUGIN_TARGETS := $(addprefix $(OMZ_PLUGINS)/,zsh-autosuggestions zsh-completions zsh-syntax-highlighting)
BREW_PREFIX        := $(shell brew --prefix 2>/dev/null)

.DEFAULT_GOAL := help

.PHONY: help deps setup setup-omz-plugins lint pre-commit check

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deps: $(BREW_PREFIX)/bin/stow $(BREW_PREFIX)/bin/pre-commit ## Install system dependencies via Homebrew

$(BREW_PREFIX)/bin/stow:
	@command -v brew >/dev/null || { echo "Error: Homebrew not found"; exit 1; }
	brew install stow

$(BREW_PREFIX)/bin/pre-commit:
	@command -v brew >/dev/null || { echo "Error: Homebrew not found"; exit 1; }
	brew install pre-commit

# setup has a recipe only for the stow loop — stow is idempotent so safe to always run.
# All other prerequisites are real files; Make skips them when already up-to-date.
setup: deps setup-omz-plugins .git/hooks/pre-commit .secrets.baseline ## Stow all packages (run after deps)
	@for pkg in $(PACKAGES); do \
		stow --no-folding -t "$$HOME" "$$pkg" && echo "stowed: $$pkg"; \
	done

.git/hooks/pre-commit: $(BREW_PREFIX)/bin/pre-commit
	pre-commit install

.secrets.baseline:
	detect-secrets scan > $@

setup-omz-plugins: $(OMZ_PLUGIN_TARGETS) ## Clone oh-my-zsh third-party plugins if missing

$(OMZ_PLUGINS)/zsh-autosuggestions:
	git clone https://github.com/zsh-users/zsh-autosuggestions $@

$(OMZ_PLUGINS)/zsh-completions:
	git clone https://github.com/zsh-users/zsh-completions $@

$(OMZ_PLUGINS)/zsh-syntax-highlighting:
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $@

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
