# Add local Applications to PATH
if [ -d "$HOME/.local/bin" ]; then
    # Add HOMEBREW python to PATH - attempting to fix "update_current_git_vars:5: command not found: python"
    export PATH="$HOME/.local/bin:$PATH"
fi

# Add local Applications to PATH
if [ -d "$HOME/Applications" ]; then
    # Add HOMEBREW python to PATH - attempting to fix "update_current_git_vars:5: command not found: python"
    export PATH="$HOME/Applications:$PATH"
fi

# Add Homebrew to PATH
if [ -f "/opt/homebrew/bin/brew" ]; then
    BREW_PREFIX="/opt/homebrew"
    export PATH="$HOME/Applications:$BREW_PREFIX/sbin:$BREW_PREFIX/bin:$PATH"

    # Add HOMEBREW python to PATH - attempting to fix "update_current_git_vars:5: command not found: python"
    export PATH="$BREW_PREFIX/opt/python@3/libexec/bin:$PATH"
fi

# Add MacOS Homebrew psql support
# $ brew install postgresql@16
if [ -d "/opt/homebrew/opt/postgresql@16/bin" ]; then
  export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
fi

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/jlaska/Projects/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/jlaska/Projects/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/jlaska/Projects/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/jlaska/Projects/google-cloud-sdk/completion.zsh.inc'; fi

if [ -d "$HOME/.npm-global/bin" ]; then
  export PATH=$HOME/.npm-global/bin:$PATH
fi

# Cargo package manager
if [ -d "$HOME/.cargo/bin" ]; then
  export PATH=$HOME/.cargo/bin:$PATH
fi
