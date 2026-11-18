# YubiKey GPG + SSH agent setup
# gpg-agent handles SSH authentication via the YubiKey Authentication subkey
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
# Linux: gpg-agent always sees the desktop, so pinentry-auto needs telling when this shell can't
# (SSH without a forwarded display, e.g. herdr started over SSH). Set a value in both cases: an
# unset variable isn't forwarded, so a curses value claimed by updatestartuptty would stick.
if [[ $OSTYPE == linux* ]]; then
  if [[ -n $SSH_CONNECTION && -z $WAYLAND_DISPLAY && -z $DISPLAY ]]; then
    export PINENTRY_USER_DATA=USE_CURSES=1
  else
    export PINENTRY_USER_DATA=USE_GUI=1
  fi
fi
# Only a real terminal should claim pinentry; non-interactive shells (scripts, agents) would
# otherwise point it at a tty nobody reads and SSH auth silently times out.
[[ -t 0 ]] && gpg-connect-agent updatestartuptty /bye > /dev/null

# Homebrew's pcsc-lite looks for pcscd's socket under the brew prefix; point ykman at the system pcscd
[[ $OSTYPE == linux* && -S /run/pcscd/pcscd.comm ]] && export PCSCLITE_CSOCK_NAME=/run/pcscd/pcscd.comm

# The personal pair and the work pair each share subkeys; gpg's stubs remember one card serial.
# yk-switch is needed when swapping within a pair (re-points the stubs at the inserted card),
# never across pairs.
alias yk-switch='gpg-connect-agent "scd serialno" "learn --force" /bye && gpg --card-status | grep -E "Serial|Reader"'
