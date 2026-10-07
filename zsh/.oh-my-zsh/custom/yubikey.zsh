# YubiKey GPG + SSH agent setup
# gpg-agent handles SSH authentication via the YubiKey Authentication subkey
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
gpg-connect-agent updatestartuptty /bye > /dev/null

# Primary and backup YubiKeys hold the same subkeys; gpg's stubs remember one card serial.
# After swapping keys, re-point the stubs at whichever card is inserted.
alias yk-switch='gpg-connect-agent "scd serialno" "learn --force" /bye && gpg --card-status | grep -E "Serial|Reader"'
