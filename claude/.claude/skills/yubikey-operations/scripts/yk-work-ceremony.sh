#!/usr/bin/env bash
# Step A: add work-only subkeys to 07E5ACD7B3165BD3 and load them onto the work YubiKeys.
# Runs on the personal Fedora workstation, network OFF, personal YubiKeys UNPLUGGED.
#
#   yk-work-ceremony.sh prepare   # online: create tmpfs workdir, stop main gpg-agent
#   (download Certify.key from Vaultwarden into $WORK/in, then: nmcli networking off)
#   yk-work-ceremony.sh run       # offline: revoke UIDs, add subkeys, backups, cards
#   yk-work-ceremony.sh resume    # offline: continue from the pre-card snapshot
#   yk-work-ceremony.sh wipe      # after uploading backups: destroy workdir, restart agent
set -euo pipefail

FP=FE149E5D50B99EC9EE32B49507E5ACD7B3165BD3
KEY_ID=07E5ACD7B3165BD3
# Card serials (from `ykman list`) gate every card step; kept out of the repo.
PERSONAL_SERIALS=${PERSONAL_SERIALS:-}
WORK_SERIALS=${WORK_SERIALS:-}
BACKUP="/run/media/$USER/YUBIKEY_BAK"   # LUKS-encrypted USB stick
REVOKE_UIDS=("James Laska <jlaska@redhat.com>" "James Laska <jlaska@ansible.com>")
EXPIRY=2y
WORK_KEYS=2
# KDF made the new Admin PIN fail verification at keytocard (GnuPG 2.4.9, fw 5.8.0); opt-in only.
KDF=${KDF:-0}
WORK="/run/user/$(id -u)/yk-ceremony"
export GNUPGHOME="$WORK/gnupg"
export PCSCLITE_CSOCK_NAME=/run/pcscd/pcscd.comm
GPG_TTY=$(tty); export GPG_TTY   # pinentry-curses prompts here

die() { printf '\n!! %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }
pause() { read -rp "    $* [Enter to continue, Ctrl-C to abort] " _; }

g() { gpg --pinentry-mode loopback "$@"; }
# Scripted answers assume every passphrase/PIN prompt appears; restart the agent so
# nothing cached skips a prompt and shifts the remaining answers.
fresh() { gpgconf --kill gpg-agent; }
withpass() { printf '%s' "$CERTIFY_PASS" | g --batch --passphrase-fd 0 "$@"; }

# tr is killed by SIGPIPE when head exits; that is expected, so mask it from pipefail.
rand() { (set +o pipefail; LC_ALL=C tr -dc "$1" </dev/urandom | head -c "$2"); }

card_serial() {
  local out
  for _ in 1 2 3; do
    out=$(gpg --card-status 2>&1) && { awk -F': ' '/^Serial number/ {print $2}' <<<"$out"; return 0; }
    sleep 2
  done
  printf '%s\n' "$out" >&2
  return 1
}

# pcscd only serves processes polkit sees in an active, local session. A shell inside a
# multiplexer started over SSH (session now closing) is refused with "Service is not running".
assert_card_access() {
  pkcheck --action-id org.debian.pcsc-lite.access_pcsc --process $$ >/dev/null 2>&1 ||
    die "polkit denies smart-card access from this shell. Open a terminal directly on the desktop (not herdr/tmux/SSH)."
}

# Print "<capabilities> <fingerprint>" for each subkey, in keyblock (edit-key index) order.
subkeys() {
  gpg -K --with-colons "$FP" | awk -F: '
    $1=="ssb" { cap=$12; pending=1; next }
    $1=="fpr" && pending { print cap, $10; pending=0 }'
}
subkey_index() { subkeys | awk -v f="$1" '$2==f { print NR; exit }'; }

assert_no_personal_keys() {
  [[ -n $PERSONAL_SERIALS && -n $WORK_SERIALS ]] ||
    die "Set PERSONAL_SERIALS and WORK_SERIALS (space-separated, from ykman list)"
  local present
  present=$(ykman list --serials 2>/dev/null || true)
  for s in $PERSONAL_SERIALS; do
    grep -qx "$s" <<<"$present" && die "Personal YubiKey $s is plugged in. Unplug it."
  done
  return 0
}

# The Vaultwarden Certify.key predates UIDs added later (noreply, photo); merge the
# published cert from the main keyring so exports keep them.
merge_public() {
  GNUPGHOME="$HOME/.gnupg" gpg --export "$FP" | gpg --import
  gpg --check-trustdb >/dev/null 2>&1 || true
  gpg -k --with-colons "$FP" | grep -qE '^uid:[^r]:.*1051173\+jlaska@users\.noreply\.github\.com' ||
    die "noreply UID missing after merge"
  gpg -k --with-colons "$FP" | grep -q '^uat:[^r]:' || die "photo UID missing after merge"
}

assert_primary_offline_safe() {
  # The primary must remain a local secret ("sec"), never "sec>" (moved to card).
  gpg -K --with-colons "$FP" | awk -F: '$1=="sec" { exit ($15 ~ /^D2760001/) ? 1 : 0 }' \
    || die "Primary key appears to be on a card. Stop and restore from backup."
}

cmd_prepare() {
  [[ $(findmnt -no FSTYPE --target "/run/user/$(id -u)") == tmpfs ]] || die "/run/user is not tmpfs"
  mkdir -p "$WORK/in" "$WORK/out"
  chmod -R 700 "$WORK"
  step "Stopping your normal gpg-agent so it does not hold the card"
  GNUPGHOME="$HOME/.gnupg" gpgconf --kill all
  cat <<EOF

Next:
  1. In Vaultwarden, save ${KEY_ID}-Certify.key DIRECTLY to:
       $WORK/in/
     (file dialog: Ctrl+L and paste the path; avoid ~/Downloads, btrfs keeps copies)
  2. Unplug both personal YubiKeys.
  3. nmcli networking off
  4. $0 run
  Avoid opening new terminals until 'wipe': your zsh profile relaunches gpg-agent.
EOF
}

cmd_run() {
  [[ $(nmcli networking) == disabled ]] || die "Networking is on. Run: nmcli networking off"
  [[ $(findmnt -no SOURCE --target "$BACKUP" 2>/dev/null) == /dev/mapper/* ]] ||
    die "Encrypted backup stick not mounted at $BACKUP"
  assert_card_access
  [[ -f "$WORK/in/${KEY_ID}-Certify.key" ]] || die "Missing $WORK/in/${KEY_ID}-Certify.key"
  assert_no_personal_keys

  step "Temporary GnuPG home in tmpfs: $GNUPGHOME"
  [[ -e $GNUPGHOME ]] && die "$GNUPGHOME exists; run 'wipe' first to start clean"
  mkdir -m 700 "$GNUPGHOME"
  cat >"$GNUPGHOME/gpg.conf" <<'EOF'
keyid-format 0xlong
with-fingerprint
cert-digest-algo SHA512
s2k-digest-algo SHA512
s2k-cipher-algo AES256
require-cross-certification
no-emit-version
EOF
  # Exclusive card access: with pcsc-shared, Firefox (NSS/OpenSC) and gsd-smartcard select the
  # PIV applet mid-session and scdaemon gets sw=6D00 ("Card error") from then on.
  grep -v '^pcsc-shared' "$HOME/.gnupg/scdaemon.conf" >"$GNUPGHOME/scdaemon.conf"
  echo "pinentry-program /usr/bin/pinentry-curses" >"$GNUPGHOME/gpg-agent.conf"

  read -rsp "    Certify passphrase: " CERTIFY_PASS; echo
  withpass --import "$WORK/in/${KEY_ID}-Certify.key"
  echo "$FP:6:" | gpg --import-ownertrust
  gpg -K --with-colons "$FP" | grep -q '^sec:u' || die "Primary secret key not present after import"
  assert_primary_offline_safe
  step "Merging newer public UIDs from ~/.gnupg"
  merge_public
  gpg -K "$FP"

  step "Revoking retired UIDs"
  for uid in "${REVOKE_UIDS[@]}"; do
    echo "    $uid"
    withpass --quick-revoke-uid "$FP" "$uid"
  done

  step "Adding work subkeys (expire $EXPIRY)"
  before=$(subkeys | awk '{print $2}')
  withpass --quick-add-key "$FP" rsa4096 sign "$EXPIRY"
  withpass --quick-add-key "$FP" ed25519 auth "$EXPIRY"
  new=$(subkeys | grep -vF "$before")
  WORK_S=$(awk '$1 ~ /s/ {print $2}' <<<"$new")
  WORK_A=$(awk '$1 ~ /a/ {print $2}' <<<"$new")
  [[ -n $WORK_S && -n $WORK_A ]] || die "Could not identify new subkeys"
  S_IDX=$(subkey_index "$WORK_S"); A_IDX=$(subkey_index "$WORK_A")
  printf '    work S: %s (key %s)\n    work A: %s (key %s)\n' "$WORK_S" "$S_IDX" "$WORK_A" "$A_IDX"
  printf 'WORK_S=%s\nWORK_A=%s\n' "$WORK_S" "$WORK_A" >"$WORK/out/work-subkeys.env"

  step "Generating revocation certificate for the whole identity"
  fresh
  printf 'y\n0\n\ny\n%s\n' "$CERTIFY_PASS" |
    g --command-fd 0 --output "$WORK/out/${KEY_ID}-revoke.asc" --gen-revoke "$FP" ||
    echo "    (failed; run 'gpg --gen-revoke $FP' by hand before wiping)"

  finish_keyring
  provision_all
}

# Export backups, copy them to the encrypted stick, and snapshot the keyring.
finish_keyring() {
  gpg -k --with-colons "$FP" | grep -c '^uid:r:' | grep -qx 2 || die "Expected 2 revoked UIDs"
  step "Exporting backups to $WORK/out"
  d=$(date +%F)
  gpg --armor --export "$FP" >"$WORK/out/${KEY_ID}-${d}.asc"
  withpass --armor --export-secret-keys "$FP" >"$WORK/out/${KEY_ID}-Certify.key"
  withpass --armor --export-secret-subkeys "$FP" >"$WORK/out/${KEY_ID}-Subkeys.key"
  gpg --export-ssh-key "${WORK_A}!" >"$WORK/out/id_yubikey_work.pub"
  ls -l "$WORK/out"

  step "Copying backups to encrypted USB: $BACKUP/${KEY_ID}-${d}"
  mkdir -p "$BACKUP/${KEY_ID}-${d}"
  cp -fv "$WORK"/out/* "$BACKUP/${KEY_ID}-${d}/"
  sync

  step "Snapshotting keyring (keytocard deletes the local copy)"
  gpgconf --kill all
  rm -rf "$WORK/gnupg.snapshot"
  cp -a "$GNUPGHOME" "$WORK/gnupg.snapshot"
  S_IDX=$(subkey_index "$WORK_S"); A_IDX=$(subkey_index "$WORK_A")
  [[ -n $S_IDX && -n $A_IDX ]] || die "Work subkeys not found after export"
  printf '    keytocard indexes: S=key %s, A=key %s\n' "$S_IDX" "$A_IDX"
}

provision_all() {
  d=$(date +%F)
  PINS=$(rand 0-9 14)
  ADMIN_PIN=${PINS:0:8}; USER_PIN=${PINS:8:6}
  printf '\n    Work YubiKey PINs (same on both). Record them now (Vaultwarden is fine):\n'
  printf '      Admin PIN: %s\n      User  PIN: %s\n' "$ADMIN_PIN" "$USER_PIN"
  pause "Recorded?"

  for n in $(seq 1 "$WORK_KEYS"); do
    provision_card "$n"
  done

  step "Done. Public outputs:"
  ls -l "$WORK/out"
  cat <<EOF

Next (see plan):
  - Backups are already on $BACKUP/${KEY_ID}-${d}. Unmount and unplug the stick.
  - nmcli networking on; upload ${KEY_ID}-Certify.key, ${KEY_ID}-Subkeys.key and
    ${KEY_ID}-revoke.asc to Vaultwarden (replace the June files), plus the new public
    ${KEY_ID}-${d}.asc and id_yubikey_work.pub.
  - Copy the public .asc, id_yubikey_work.pub and work-subkeys.env somewhere persistent
    (e.g. ~/yk-ceremony-public/) before wiping.
  - $0 wipe
EOF
}

provision_card() {
  local n=$1 serial
  # Each card starts from the pre-transfer snapshot so it receives the same subkeys.
  gpgconf --kill all
  rm -rf "$GNUPGHOME"; cp -a "$WORK/gnupg.snapshot" "$GNUPGHOME"

  step "Work YubiKey #$n"
  pause "Insert ONLY work YubiKey #$n (personal keys stay unplugged)"
  assert_no_personal_keys
  serial=$(card_serial) || die "gpg cannot read the card (error above)"
  [[ -n $serial ]] || die "No OpenPGP card detected"
  for s in $PERSONAL_SERIALS; do [[ $serial == "$s" ]] && die "Card $serial is a PERSONAL YubiKey"; done
  [[ " $WORK_SERIALS " == *" $serial "* ]] || die "Card $serial is not one of the work YubiKeys ($WORK_SERIALS)"
  echo "    serial $serial"

  local status
  status=$(gpg --card-status)
  if ! grep -qE '^Signature key \.+: \[none\]' <<<"$status" ||
     ! grep -qE '^Authentication key: \[none\]' <<<"$status"; then
    grep -E 'key \.|Authentication key' <<<"$status"
    echo "    Card already holds OpenPGP keys."
    read -rp "    Type RESET to wipe the OpenPGP applet on $serial (FIDO2/PIV untouched): " ans
    [[ $ans == RESET ]] || die "Aborted"
  fi
  # Always start from factory OpenPGP state so default PINs apply and retries are full.
  echo "    Resetting OpenPGP applet"
  gpgconf --kill scdaemon
  ykman --device "$serial" openpgp reset -f
  gpgconf --kill scdaemon

  if (( KDF )); then
  echo "    KDF"
  gpg --command-fd 0 --pinentry-mode loopback --card-edit <<EOF >/dev/null
admin
kdf-setup
12345678
quit
EOF
  fi
  echo "    Admin PIN"
  gpg --command-fd 0 --pinentry-mode loopback --change-pin <<EOF >/dev/null
3
12345678
$ADMIN_PIN
$ADMIN_PIN
q
EOF
  echo "    User PIN"
  gpg --command-fd 0 --pinentry-mode loopback --change-pin <<EOF >/dev/null
1
123456
$USER_PIN
$USER_PIN
q
EOF
  fresh
  echo "    Login attribute"
  gpg --command-fd 0 --pinentry-mode loopback --card-edit <<EOF >/dev/null
admin
login
yk.$(rand a-z0-9 16)
$ADMIN_PIN
quit
EOF
  # Login data can only be written with the Admin PIN, so this proves the new Admin PIN
  # verifies before keytocard spends a retry on it.
  status=$(gpg --card-status)
  grep -E '^(Login data|PIN retry counter|KDF setting)' <<<"$status" | sed 's/^/    /'
  grep -qE '^Login data \.+: yk\.' <<<"$status" ||
    die "Admin PIN did not verify (login attribute not set); stopping before keytocard"

  # Factory slots are rsa2048 and keytocard does not convert them ("Invalid value").
  # Menu answers: Signature RSA 4096, Encryption RSA 4096 (unused), Authentication ECC Curve 25519.
  # The Admin PIN is asked by pinentry.
  fresh
  echo "    Key attributes (pinentry asks for the Admin PIN)"
  gpg --command-fd 0 --card-edit <<EOF >/dev/null
admin
key-attr
1
4096
1
4096
2
1
quit
EOF
  status=$(gpg --card-status)
  grep -E '^Key attributes' <<<"$status" | sed 's/^/    /'
  grep -qE '^Key attributes \.+: rsa4096 rsa4096 ed25519' <<<"$status" ||
    die "Key attributes not set to rsa4096 rsa4096 ed25519; stopping before keytocard"

  fresh
  # keytocard may first change the slot's key attributes (factory rsa2048), which asks for
  # the Admin PIN before the passphrase. Scripted secrets then land in the wrong prompt, so
  # only menu answers go to command-fd and pinentry asks for each secret by name.
  echo "    keytocard: work S (key $S_IDX) -> slot 1"
  echo "    pinentry will ask for the Certify passphrase and the Admin PIN (maybe twice)"
  gpg --command-fd 0 --edit-key "$FP" <<EOF
key $S_IDX
keytocard
1
save
EOF
  fresh
  echo "    keytocard: work A (key $A_IDX) -> slot 3"
  gpg --command-fd 0 --edit-key "$FP" <<EOF
key $A_IDX
keytocard
3
save
EOF
  assert_primary_offline_safe

  echo "    Touch policy"
  gpgconf --kill scdaemon
  ykman --device "$serial" openpgp keys set-touch sig on -a "$ADMIN_PIN" -f
  ykman --device "$serial" openpgp keys set-touch aut on -a "$ADMIN_PIN" -f

  step "Verify card $serial"
  gpg --card-status | grep -E 'Serial|Login|KDF|UIF|Signature key|Authentication key'
  gpg -K "$FP" | grep -E "^(sec|ssb>)|card-no"
  local card_fprs
  card_fprs=$(gpg --card-status --with-colons | awk -F: '$1=="fpr" {print $2, $4}')
  grep -q "$WORK_S" <<<"$card_fprs" && grep -q "$WORK_A" <<<"$card_fprs" ||
    die "Card $serial does not hold the expected work subkeys"
  pause "Card $serial OK. Remove it."
}

cmd_resume() {
  [[ $(nmcli networking) == disabled ]] || die "Networking is on. Run: nmcli networking off"
  [[ $(findmnt -no SOURCE --target "$BACKUP" 2>/dev/null) == /dev/mapper/* ]] ||
    die "Encrypted backup stick not mounted at $BACKUP"
  [[ -d "$WORK/gnupg.snapshot" && -f "$WORK/out/work-subkeys.env" ]] || die "No snapshot to resume from"
  assert_card_access
  assert_no_personal_keys
  gpgconf --kill all 2>/dev/null || true
  rm -rf "$GNUPGHOME"; cp -a "$WORK/gnupg.snapshot" "$GNUPGHOME"
  # shellcheck source=/dev/null
  . "$WORK/out/work-subkeys.env"
  S_IDX=$(subkey_index "$WORK_S"); A_IDX=$(subkey_index "$WORK_A")
  [[ -n $S_IDX && -n $A_IDX ]] || die "Work subkeys not found in snapshot"
  printf '    work S: %s (key %s)\n    work A: %s (key %s)\n' "$WORK_S" "$S_IDX" "$WORK_A" "$A_IDX"
  assert_primary_offline_safe
  read -rsp "    Certify passphrase: " CERTIFY_PASS; echo
  step "Merging newer public UIDs from ~/.gnupg"
  merge_public
  gpg -K "$FP"
  finish_keyring
  provision_all
}

cmd_wipe() {
  gpgconf --kill all 2>/dev/null || true
  rm -rf "$WORK"
  unset GNUPGHOME
  gpgconf --launch gpg-agent
  echo "Wiped $WORK and restarted your normal gpg-agent."
}

case "${1:-}" in
  prepare) cmd_prepare ;;
  run) cmd_run ;;
  resume) cmd_resume ;;
  wipe) cmd_wipe ;;
  *) sed -n '2,10p' "$0"; exit 1 ;;
esac
