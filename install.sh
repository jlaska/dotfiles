#!/bin/bash
set -e

# Install GNU Stow if not present
if ! command -v stow &>/dev/null; then
  brew install stow
fi

# Stow all packages (each top-level directory is a package)
cd "$(dirname "$0")"
for pkg in */; do
  pkg="${pkg%/}"
  # Skip non-package directories
  [[ "$pkg" == "." || "$pkg" == ".git" ]] && continue
  stow --no-folding -t "$HOME" "$pkg"
  echo "stowed: $pkg"
done
