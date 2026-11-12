OS                 := $(shell uname -s)
OS_LOWER           := $(shell uname -s | tr '[:upper:]' '[:lower:]')
# Packages suffixed -darwin / -linux are only stowed on the matching OS
ALL_PACKAGES       := $(shell find . -mindepth 1 -maxdepth 1 -type d -not -name '.*' | sed 's|./||')
PACKAGES           := $(filter-out %-darwin %-linux,$(ALL_PACKAGES)) $(filter %-$(OS_LOWER),$(ALL_PACKAGES))
OMZ_PLUGINS        := $(HOME)/.oh-my-zsh/custom/plugins
OMZ_PLUGIN_TARGETS := $(addprefix $(OMZ_PLUGINS)/,zsh-autosuggestions zsh-completions zsh-syntax-highlighting)
VIM_PACK           := $(HOME)/.vim/pack/plugins/start
BREWFILE           := brew/Brewfile
# Optional profiles: brew/Brewfile.<name>, discovered automatically
BREW_PROFILES      := $(sort $(patsubst brew/Brewfile.%,%,$(wildcard brew/Brewfile.*)))
BREW_PROFILE_TARGETS := $(addprefix install-brewfile-,$(BREW_PROFILES))
PROFILES           ?=
BREW_DUMP          ?= $(or $(TMPDIR),/tmp)/Brewfile.dump
VIM_PLUGIN_TARGETS := $(addprefix $(VIM_PACK)/,ansible-vim ctrlp.vim editorconfig-vim flake8-vim syntastic vim-base64 vim-fugitive vim-gnupg vim-markdown vim-python-pep8-indent)

.DEFAULT_GOAL := help

.PHONY: $(BREW_PROFILE_TARGETS) help install-xcode install-brew-cli install-deps install install-brew brew-profiles brew-dump install-omz-plugins install-vim-plugins install-mise install-docker-config import-keys lint pre-commit check

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

ifeq ($(OS),Darwin)
install-xcode: ## Install Xcode Command Line Tools if missing
	@xcode-select -p >/dev/null 2>&1 || { echo "Installing Xcode Command Line Tools..."; xcode-select --install; echo "Re-run 'make install' after Xcode CLT installation completes."; exit 1; }
else
install-xcode: ## Install Xcode Command Line Tools if missing
	@echo "Skipping 'install-xcode' target on $(OS)."
endif

install-brew-cli: install-xcode ## Install Homebrew if missing
	@command -v brew >/dev/null 2>&1 || { echo "Installing Homebrew..."; /bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; }

install-deps: install-brew-cli ## Install system dependencies via Homebrew
	@command -v stow >/dev/null 2>&1 || brew install stow
	@command -v pre-commit >/dev/null 2>&1 || brew install pre-commit

# install has a recipe only for the stow loop — stow is idempotent so safe to always run.
# All other prerequisites are real files; Make skips them when already up-to-date.
install: install-deps install-omz-plugins install-vim-plugins .git/hooks/pre-commit .secrets.baseline ## Stow all packages
	@for pkg in $(PACKAGES); do \
		stow --no-folding -t "$$HOME" "$$pkg" && echo "stowed: $$pkg"; \
	done
	@$(MAKE) --no-print-directory install-mise
	@$(MAKE) --no-print-directory install-docker-config

install-mise: ## Install tools pinned in ~/.config/mise/config.toml (requires mise from Brewfile)
	@command -v mise >/dev/null 2>&1 && mise install --yes || echo "mise not found; run 'make install-brew' first"

# ~/.docker/config.json is not stowed: the docker CLI and Docker Desktop rewrite it
# (replacing a stow symlink) and it can hold registry auth. Merge only `credsStore`.
# Linux: secretservice helper from mise. macOS: keep Docker Desktop's `desktop` if set,
# otherwise osxkeychain (brew docker-credential-helper).
DOCKER_CONFIG_FILE := $(HOME)/.docker/config.json
ifeq ($(OS),Darwin)
DOCKER_JQ_FILTER   := .credsStore //= "osxkeychain"
else
DOCKER_JQ_FILTER   := .credsStore = "secretservice"
endif

install-docker-config: ## Set credsStore in ~/.docker/config.json (preserves other keys, never touches auths)
	@command -v jq >/dev/null 2>&1 || { echo "jq not found; install it (dnf/brew install jq)"; exit 1; }
	@umask 077 && mkdir -p $(dir $(DOCKER_CONFIG_FILE)) && \
		{ [ -s $(DOCKER_CONFIG_FILE) ] || echo '{}' > $(DOCKER_CONFIG_FILE); } && \
		jq '$(DOCKER_JQ_FILTER)' $(DOCKER_CONFIG_FILE) > $(DOCKER_CONFIG_FILE).tmp && \
		command mv -f $(DOCKER_CONFIG_FILE).tmp $(DOCKER_CONFIG_FILE) && \
		echo "docker credsStore: $$(jq -r .credsStore $(DOCKER_CONFIG_FILE))"

install-brew: ## Install core Brewfile; opt in with PROFILES="k8s ai" (or "all"), or make install-brewfile-<profile>
	@command -v brew >/dev/null || { echo "Error: Homebrew not found"; exit 1; }
	@profiles="$(PROFILES)"; [ "$$profiles" = all ] && profiles="$(BREW_PROFILES)"; \
	for p in $$profiles; do \
		[ -f brew/Brewfile.$$p ] || { echo "Error: unknown profile '$$p' (available: $(BREW_PROFILES))"; exit 1; }; \
	done; \
	brew bundle install --file=$(BREWFILE) --no-upgrade || exit $$?; \
	for p in $$profiles; do \
		$(call brew_profile,$$p) || exit $$?; \
	done

# Shared by install-brew PROFILES=... and install-brewfile-<name> (no $(MAKE) here: `make -n` would run it).
brew_profile = { echo "==> profile: $(1)"; brew bundle install --file=brew/Brewfile.$(1) --no-upgrade; }

# install-brewfile-<name> installs brew/Brewfile.<name> only (no core). Known profiles use a static
# pattern so they can be .PHONY; the fallback rule reports unknown names.
$(BREW_PROFILE_TARGETS): install-brewfile-%:
	@command -v brew >/dev/null || { echo "Error: Homebrew not found"; exit 1; }
	@$(call brew_profile,$*)

install-brewfile-%:
	@echo "Error: unknown profile '$*' (available: $(BREW_PROFILES))"; exit 1

brew-profiles: ## List optional Brewfile profiles
	@echo "Core: $(BREWFILE) (make install-brew)"
	@echo "Optional profiles (make install-brewfile-<name>, or make install-brew PROFILES=\"<name> ...\" / PROFILES=all):"
	@for p in $(BREW_PROFILES); do printf "  %-10s %s\n" "$$p" "$$(head -1 brew/Brewfile.$$p | sed 's/^# //; s/ Install:.*//')"; done

brew-dump: ## Dump installed packages to a temp Brewfile for sorting into brew/Brewfile*
	@command -v brew >/dev/null || { echo "Error: Homebrew not found"; exit 1; }
	brew bundle dump --file=$(BREW_DUMP) --describe --force
	@grep -q 'if OS.mac?' $(BREW_DUMP) || echo "WARNING: dump dropped OS guards (podman, qemu); re-add 'if OS.mac?' when sorting"
	@echo "Wrote $(BREW_DUMP); diff against brew/Brewfile* and copy new entries into the right profile."

.git/hooks/pre-commit:
	@command -v pre-commit >/dev/null 2>&1 && pre-commit install || echo "pre-commit not yet installed, skipping hook setup"

.secrets.baseline:
	detect-secrets scan > $@

install-omz-plugins: $(OMZ_PLUGIN_TARGETS) ## Clone oh-my-zsh third-party plugins if missing

$(OMZ_PLUGINS)/zsh-autosuggestions:
	git clone https://github.com/zsh-users/zsh-autosuggestions $@

$(OMZ_PLUGINS)/zsh-completions:
	git clone https://github.com/zsh-users/zsh-completions $@

$(OMZ_PLUGINS)/zsh-syntax-highlighting:
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $@

install-vim-plugins: $(VIM_PLUGIN_TARGETS) ## Clone vim native packages if missing

$(VIM_PACK)/ansible-vim:
	git clone https://github.com/pearofducks/ansible-vim.git $@

$(VIM_PACK)/ctrlp.vim:
	git clone https://github.com/kien/ctrlp.vim.git $@

$(VIM_PACK)/editorconfig-vim:
	git clone https://github.com/editorconfig/editorconfig-vim.git $@

$(VIM_PACK)/flake8-vim:
	git clone https://github.com/andviro/flake8-vim.git $@

$(VIM_PACK)/syntastic:
	git clone https://github.com/scrooloose/syntastic.git $@

$(VIM_PACK)/vim-base64:
	git clone https://github.com/christianrondeau/vim-base64.git $@

$(VIM_PACK)/vim-fugitive:
	git clone https://github.com/tpope/vim-fugitive.git $@

$(VIM_PACK)/vim-gnupg:
	git clone https://github.com/jamessan/vim-gnupg.git $@

$(VIM_PACK)/vim-markdown:
	git clone https://github.com/plasticboy/vim-markdown.git $@

$(VIM_PACK)/vim-python-pep8-indent:
	git clone https://github.com/hynek/vim-python-pep8-indent.git $@

# Private key material lives in Vaultwarden, copied into the macOS Keychain per machine.
# Each item is a single-line base64 value (see README "New machine setup").
GPG_KEYCHAIN_ITEMS := gpg-sops-key gpg-argocd-secrets-key
AGE_KEY_FILE       := $(HOME)/.config/sops/age/keys.txt

import-keys: ## Import GPG public/secret keys, ownertrust and SOPS age key from Keychain
	curl -fsSL https://github.com/jlaska.gpg | gpg --import
	@for item in $(GPG_KEYCHAIN_ITEMS); do \
		security find-generic-password -s "$$item" -a "$$USER" -w | base64 -d | gpg --batch --import && echo "imported: $$item"; \
	done
	security find-generic-password -s gpg-ownertrust -a "$$USER" -w | base64 -d | gpg --import-ownertrust
	@mkdir -p $(dir $(AGE_KEY_FILE)) && umask 077 && \
		security find-generic-password -s sops-age-key -a "$$USER" -w | base64 -d > $(AGE_KEY_FILE) && echo "wrote: $(AGE_KEY_FILE)"
	gpg --card-status >/dev/null && echo "YubiKey stubs created"

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
