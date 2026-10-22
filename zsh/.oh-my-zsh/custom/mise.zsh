# mise (https://mise.jdx.dev) - polyglot tool version manager
# Generate the activation hooks at shell startup instead of caching them here:
# `mise activate` output embeds PATH snapshots and the brew path of the binary.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi
