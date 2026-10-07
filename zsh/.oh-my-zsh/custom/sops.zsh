# SOPS age identity (populated by `make import-keys`); pin path so sops doesn't fall back to ~/Library
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
