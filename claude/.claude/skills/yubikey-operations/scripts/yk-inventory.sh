#!/usr/bin/env bash
# Read-only inventory of GPG/SSH/YubiKey tooling and keys. Prints fingerprints
# and key listings only; never reads or prints private key material.
# Works with macOS bash 3.2 and Linux bash 5.

h() { printf '\n===== %s\n' "$*"; }
ver() {
  local c=$1; shift
  if p=$(command -v "$c" 2>/dev/null); then
    printf '%-22s %s  ' "$c" "$p"; "$c" "$@" </dev/null 2>&1 | head -1
  else
    printf '%-22s MISSING\n' "$c"
  fi
}

h System
uname -srm
[ -r /etc/os-release ] && . /etc/os-release && echo "$PRETTY_NAME"
command -v sw_vers >/dev/null && sw_vers | tr '\n' ' ' && echo
echo "shell=$SHELL bash=$BASH_VERSION"
echo "brew=$(command -v brew || echo none) $(brew --prefix 2>/dev/null)"
command -v profiles >/dev/null && echo "MDM enrolled: $(profiles status -type enrollment 2>/dev/null | tr '\n' ' ')"

h Commands
ver gpg --version
ver gpg-agent --version
ver gpgconf --version
ver gpg-connect-agent --version
ver pinentry --version
ver pinentry-mac --version
ver pinentry-gnome3 --version
ver pinentry-curses --version
ver ykman --version
ver ssh -V
ver git --version
ver gh --version
ver stow --version
ver cryptsetup --version
ver nmcli --version
ver pcscd --version
ls -la /usr/libexec/scdaemon "$(gpgconf --list-components 2>/dev/null | awk -F: '/^scdaemon/ {print $3}')" 2>/dev/null

h "pcscd / smartcard"
if command -v systemctl >/dev/null; then
  systemctl is-active pcscd.socket pcscd.service 2>&1 | paste -sd' ' -
fi
ls -la /run/pcscd/ 2>/dev/null
echo "PCSCLITE_CSOCK_NAME=${PCSCLITE_CSOCK_NAME:-unset}"
command -v ykman >/dev/null && ykman list 2>&1

h "gpg config"
echo "GNUPGHOME=${GNUPGHOME:-unset} SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-unset}"
gpgconf --list-dirs 2>&1 | grep -E 'homedir|agent-socket|agent-ssh-socket'
for f in gpg.conf gpg-agent.conf scdaemon.conf sshcontrol; do
  p="$HOME/.gnupg/$f"
  [ -e "$p" ] && { echo "--- $p -> $(readlink "$p" || echo regular)"; grep -v '^\s*#' "$p" | grep -v '^\s*$'; }
done

h "gpg public keys"
gpg -k --keyid-format long 2>&1 | grep -E '^(pub|sub|uid)' | grep -v revoked
h "gpg secret keys (stubs: # = offline, > = on card)"
gpg -K --keyid-format long --with-keygrip 2>&1 | grep -E '^(sec|ssb|uid)|Keygrip|card-no'
echo "private-keys-v1.d entries: $(ls "$HOME/.gnupg/private-keys-v1.d" 2>/dev/null | wc -l | tr -d ' ')"

h "card status"
gpg --card-status 2>&1 | grep -E 'Serial|Reader|Login|KDF|PIN retry|UIF|Key attributes|key \.|General key'

h "ssh"
ls -la "$HOME/.ssh" 2>&1
for f in "$HOME"/.ssh/*.pub; do [ -e "$f" ] && ssh-keygen -lf "$f"; done
for f in "$HOME"/.ssh/id_*; do
  case "$f" in *.pub) ;; *) [ -e "$f" ] && echo "PRIVATE KEY FILE: $f ($(head -1 "$f" | cut -c1-40))";; esac
done
echo "--- agent keys"
ssh-add -l 2>&1
echo "--- effective config for github.com"
ssh -G github.com 2>/dev/null | grep -Ei '^(user|identityfile|identitiesonly|forwardagent|identityagent) '

h "git"
git config --global --list --show-origin 2>&1 | grep -Ei 'user\.|gpg|sign|include|credential'

h "github (public)"
curl -s https://github.com/jlaska.keys | while read -r l; do echo "$l" | ssh-keygen -lf -; done
