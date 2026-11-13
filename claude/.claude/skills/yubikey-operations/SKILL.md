---
name: yubikey-operations
description: Operate and troubleshoot James's YubiKey-backed OpenPGP/SSH identity (cert 0x07E5ACD7B3165BD3) with separate personal and work key pairs. Use for YubiKey, GPG card, subkey, keytocard, expiry, revocation, yk-switch, gpg-agent/pinentry, "agent refused operation", "Card error", commit-signing or GitHub SSH/GPG key tasks on the Fedora workstation or the work MacBook.
---

# YubiKey operations

One OpenPGP certificate, one GitHub identity (`jlaska`), and two separate sets of
hardware keys. The primary (Certify) key is offline. Day-to-day keys live only on
YubiKeys.

## Identity model

Cert `FE149E5D50B99EC9EE32B49507E5ACD7B3165BD3`; public copy at <https://github.com/jlaska.gpg>.

| `key N` | Key ID | Use | Lives on | Expires |
|---|---|---|---|---|
| — | `07E5ACD7B3165BD3` | Certify (primary) | offline backup only | — |
| 1 | `CC27416519C35FF9` | Sign | personal pair (5C + 5C Nano) | 2028-06-15 |
| 2 | `1D8AC3D87178922D` | Encrypt | personal pair | 2028-06-15 |
| 3 | `DA11994400ACAF40` | Auth (SSH) | personal pair | 2028-06-15 |
| 4 | `734AE42F2DC544DF` | Sign | work pair (5C NFC + 5C Nano) | 2028-11-05 |
| 5 | `620CC9D10D505A4C` | Auth (SSH) | work pair | 2028-11-05 |

The `key N` numbers are the order of the subkeys in `gpg --edit-key`. Check them with
`gpg -K` before running `keytocard`.

| Machine | Cards | Git signing key | SSH `IdentityFile` (in `~/.ssh/config.local`) |
|---|---|---|---|
| Fedora workstation (personal) | personal pair | `CC27416519C35FF9!` (from `git/.gitconfig`) | `~/.ssh/id_yubikey.pub` |
| Work MacBook (MDM-managed) | work pair | `734AE42F2DC544DF!` (from `~/.gitconfig.local`) | `~/.ssh/id_yubikey_work.pub` |

Commit email is always `1051173+jlaska@users.noreply.github.com`. The UIDs
`jlaska@redhat.com` and `jlaska@ansible.com` are revoked.

## Invariants (never violate)

- **Never put personal keys (1–3) on work hardware.** Work cards hold only keys 4 and 5,
  and the work Mac keyring shows keys 1–3 as `ssb#`.
- **The primary key stays offline.** `gpg -K` must show `sec#` on daily machines. In a
  ceremony keyring it must stay `sec` and must never become `sec>`.
- **Secret key material only goes into a throwaway `GNUPGHOME` on tmpfs**
  (`/run/user/$UID/...`), with networking off. Never put it in `~/Downloads`, because
  btrfs snapshots keep copies.
- **Never ask for, echo or log PINs or the Certify passphrase.** The user types them
  into pinentry. If the user pastes one into chat, tell them it's now exposed and should
  be changed.
- Pin key IDs with `!` (for example `CC27416519C35FF9!`). Without it, gpg picks the
  newest signing subkey, which may be one that isn't on the inserted card.

## Backups

These are kept outside this repo:

- an encrypted (LUKS) USB stick labelled `YUBIKEY_BAK`, which has a dated folder and a
  README
- a Vaultwarden item

Both hold:

- `07E5ACD7B3165BD3-Certify.key` (primary key and all subkeys)
- `07E5ACD7B3165BD3-Subkeys.key`
- `07E5ACD7B3165BD3-revoke.asc` (revocation certificate)
- the public `.asc`
- `id_yubikey_work.pub`

The PINs and passphrase are in Vaultwarden only. Use `bw` with
`BW_SESSION=$(secret-tool lookup service bw-session)`.

## Procedures

See [references/procedures.md](references/procedures.md) for:

- replacing or adding a YubiKey
- extending expiry
- revoking the work keys or the whole cert
- refreshing backups
- publishing the cert to GitHub and keys.openpgp.org

Scripts:

- `scripts/yk-inventory.sh`: read-only inventory of tools, keys, cards, SSH and git
  config. Run it on each machine before changing anything.
- `scripts/yk-work-ceremony.sh`: the 2026-11-06 ceremony that added the work subkeys,
  revoked the retired UIDs, and provisioned both work cards. It's kept as a record. Its
  `provision_card` function is the tested sequence for setting up a card. It needs
  `PERSONAL_SERIALS` and `WORK_SERIALS` in the environment; get them from `ykman list`.

## Troubleshooting (learned the hard way)

| Symptom | Cause | Fix |
|---|---|---|
| `agent refused operation` (ssh) or `signing failed: Timeout` | The PIN cache expired (4 h, max 8 h) and pinentry opened on another screen or a tty nobody reads | In the terminal you're using, run `gpg-connect-agent updatestartuptty /bye` and retry. If the agent must be restarted: on the desktop, `gpgconf --kill gpg-agent` first; over SSH (`$SSH_CONNECTION` set), use `gpgconf --kill gpg-agent; systemctl --user start gpg-agent.socket gpg-agent-ssh.socket` instead, because an agent started from the SSH session can't reach pcscd (see `Service is not running` below). Over SSH, the touch and PIN have to happen on the machine that has the card |
| gpg asks you to insert a card with a different serial | The stubs remember the other card of the pair | `yk-switch` (alias in `zsh/.oh-my-zsh/custom/yubikey.zsh`) |
| `Card error` / `sw=6D00` partway through a card operation | With `pcsc-shared`, Firefox (NSS/OpenSC) and `gsd-smartcard` switch the YubiKey applet | For card admin: remove `pcsc-shared` from the temporary `scdaemon.conf`, quit Firefox, run `systemctl --user stop org.gnome.SettingsDaemon.Smartcard.target`, and re-plug the card |
| `Service is not running` / `PC/SC not available` on Fedora | polkit allows pcscd access only from an active local session. Shells under SSH or a multiplexer started over SSH are refused | Run card commands in a terminal opened on the desktop. If gpg-agent was restarted from an SSH shell, its scdaemon inherits that session; `ssh-add -L` then shows `The agent has no identities` and ssh says `Load key ...pub: invalid format`. Restart it under the systemd user manager: `gpgconf --kill gpg-agent; systemctl --user start gpg-agent.socket gpg-agent-ssh.socket`, then `gpg-connect-agent updatestartuptty /bye` in your terminal |
| `keytocard` fails with `Invalid value` | Factory slots are rsa2048 | `gpg --edit-card` → `admin` → `key-attr`: RSA 4096 / RSA 4096 / ECC Curve 25519 |
| `Bad PIN` during scripted `keytocard` | In loopback mode, the order of the prompts shifts (Admin PIN before passphrase) | Only send menu answers to `--command-fd`; let pinentry ask for each secret |
| ssh says `Load key ...pub: invalid format` | That `.pub` file belongs to a key the local agent doesn't hold, or the agent can't see the card at all | Check `ssh-add -L` and `gpg --card-status`. If the agent has no identities and the card isn't visible, see `Service is not running`. Otherwise list only this machine's key in `~/.ssh/config.local` |
| ssh says `bad permissions` on `id_yubikey*.pub` | ssh treats an `IdentityFile` like a private key | `chmod 600` the file in the repo. Git doesn't track this mode, so redo it after a fresh clone |
| ssh to the work Mac is refused | MDM or a restart turned Remote Login off | Have the user turn on System Settings → General → Sharing → Remote Login |
| `git pull` on a new machine fails before the SSH key file exists | Chicken-and-egg | `git -c url.https://github.com/.insteadOf=git@github.com: pull` |

## Verifying

```sh
gpg --card-status | grep -E 'Serial|Signature key|Authentication key|UIF'
gpg -K 07E5ACD7B3165BD3 | grep -E '^(sec|ssb)'      # sec#; ssb> for this machine's pair
ssh-add -L                                           # only this machine's key
ssh -T git@github.com                                # touch → "Hi jlaska!"
git log -1 --format='%G? %GK'                        # G + the expected subkey
```

On GitHub, check
`gh api 'repos/<owner>/<repo>/commits?per_page=5' --jq '.[].commit.verification'`.
Running `gh api user/gpg_keys` or `user/keys` needs the `admin:gpg_key` or
`admin:public_key` scopes.
