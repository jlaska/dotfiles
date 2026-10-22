# mise (https://mise.jdx.dev) - polyglot tool version manager
# Named zz-* so oh-my-zsh sources it after path.zsh and the other PATH edits;
# mise must activate last to keep its tool paths first in PATH.
# Generate the activation hooks at shell startup instead of caching them here:
# `mise activate` output embeds PATH snapshots and the brew path of the binary.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi
