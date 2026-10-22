# Non-interactive shells (scripts, cron, GUI-launched tools, `zsh -c`) skip
# .zshrc, so they never run `mise activate`. Put the shims on PATH so they
# still resolve mise-managed tools. Interactive shells activate in zz-mise.zsh,
# which puts the real tool paths ahead of the shims.
if [ -d "$HOME/.local/share/mise/shims" ]; then
    export PATH="$HOME/.local/share/mise/shims:$PATH"
fi
