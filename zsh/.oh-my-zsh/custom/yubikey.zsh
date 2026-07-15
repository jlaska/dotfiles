# YubiKey GPG + SSH agent setup
# gpg-agent handles SSH authentication via the YubiKey Authentication subkey
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
gpg-connect-agent updatestartuptty /bye > /dev/null
