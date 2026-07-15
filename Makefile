PACKAGES           := $(shell find . -mindepth 1 -maxdepth 1 -type d -not -name '.*' | sed 's|./||')
OMZ_PLUGINS        := $(HOME)/.oh-my-zsh/custom/plugins
OMZ_PLUGIN_TARGETS := $(addprefix $(OMZ_PLUGINS)/,zsh-autosuggestions zsh-completions zsh-syntax-highlighting)
VIM_PACK           := $(HOME)/.vim/pack/plugins/start
VIM_PLUGIN_TARGETS := $(addprefix $(VIM_PACK)/,ansible-vim ctrlp.vim editorconfig-vim flake8-vim syntastic vim-base64 vim-fugitive vim-gnupg vim-markdown vim-python-pep8-indent)
BREW_PREFIX        := $(shell brew --prefix 2>/dev/null)

.DEFAULT_GOAL := help

.PHONY: help install-deps install install-omz-plugins install-vim-plugins lint pre-commit check

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install-deps: $(BREW_PREFIX)/bin/stow $(BREW_PREFIX)/bin/pre-commit ## Install system dependencies via Homebrew

$(BREW_PREFIX)/bin/stow:
	@command -v brew >/dev/null || { echo "Error: Homebrew not found"; exit 1; }
	brew install stow

$(BREW_PREFIX)/bin/pre-commit:
	@command -v brew >/dev/null || { echo "Error: Homebrew not found"; exit 1; }
	brew install pre-commit

# install has a recipe only for the stow loop — stow is idempotent so safe to always run.
# All other prerequisites are real files; Make skips them when already up-to-date.
install: install-deps install-omz-plugins install-vim-plugins .git/hooks/pre-commit .secrets.baseline ## Stow all packages (run after install-deps)
	@for pkg in $(PACKAGES); do \
		stow --no-folding -t "$$HOME" "$$pkg" && echo "stowed: $$pkg"; \
	done

.git/hooks/pre-commit: $(BREW_PREFIX)/bin/pre-commit
	pre-commit install

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
