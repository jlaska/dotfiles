# YubiKey GPG + SSH agent setup
# gpg-agent handles SSH authentication via the YubiKey Authentication subkey
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
# Only a real terminal should claim pinentry; non-interactive shells (scripts, agents) would
# otherwise point it at a tty nobody reads and SSH auth silently times out.
[[ -t 0 ]] && gpg-connect-agent updatestartuptty /bye > /dev/null

# Homebrew's pcsc-lite looks for pcscd's socket under the brew prefix; point ykman at the system pcscd
[[ $OSTYPE == linux* && -S /run/pcscd/pcscd.comm ]] && export PCSCLITE_CSOCK_NAME=/run/pcscd/pcscd.comm

# The personal pair and the work pair each share subkeys; gpg's stubs remember one card serial.
# yk-switch is needed when swapping within a pair (re-points the stubs at the inserted card),
# never across pairs.
alias yk-switch='gpg-connect-agent "scd serialno" "learn --force" /bye && gpg --card-status | grep -E "Serial|Reader"'
