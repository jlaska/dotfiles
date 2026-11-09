# YubiKey procedures

Every procedure that uses the Certify key follows the same pattern:

- Run it on the Fedora workstation, in a desktop terminal (not SSH or a multiplexer).
- Turn networking off (`nmcli networking off`).
- Plug in only the cards being worked on.
- Use the backup from the encrypted USB stick or Vaultwarden.

```sh
export GNUPGHOME=$(mktemp -d -p /run/user/$(id -u)) && chmod 700 "$GNUPGHOME"
grep -v '^pcsc-shared' ~/.gnupg/scdaemon.conf > "$GNUPGHOME/scdaemon.conf"   # exclusive card access
gpg --import /run/media/$USER/YUBIKEY_BAK/<dated-folder>/07E5ACD7B3165BD3-Certify.key
echo 'FE149E5D50B99EC9EE32B49507E5ACD7B3165BD3:6:' | gpg --import-ownertrust
# ... task ...
gpgconf --kill all && rm -rf "$GNUPGHOME" && unset GNUPGHOME
```

Before any card admin, quit Firefox and run
`systemctl --user stop org.gnome.SettingsDaemon.Smartcard.target`. Start it again
afterwards.

## Lost one card of a pair

Nothing needs restoring, because the other card holds the same keys. Insert it and run
`yk-switch`. To make a replacement, see the next section.

## New or replacement YubiKey

1. Reset the card: `ykman --device <serial> openpgp reset`, then
   `gpgconf --kill scdaemon`.
2. Set the PINs with `gpg --change-pin`. Choose `3` for the Admin PIN (default
   `12345678`), then `1` for the User PIN (default `123456`). Use the same PINs as the
   other card in the pair (Vaultwarden).
3. In `gpg --edit-card`:
   - `admin`
   - `login` → `yk.<random>`
   - `key-attr` → `1`/`4096`, `1`/`4096`, `2`/`1` (RSA 4096, RSA 4096, Curve 25519)
4. In `gpg --edit-key FE149E5D50B99EC9EE32B49507E5ACD7B3165BD3`:
   - Select one subkey at a time. Before each `keytocard`, check that only that line has
     the `*`.
   - Personal card: key `1` → slot `1`, key `2` → slot `2`, key `3` → slot `3`.
   - Work card: key `4` → slot `1`, key `5` → slot `3`. **Never keys 1–3.**
   - `save`
5. Turn on touch:

   ```sh
   gpgconf --kill scdaemon
   ykman --device <serial> openpgp keys set-touch sig on
   ykman --device <serial> openpgp keys set-touch aut on
   ```

6. Check it: `gpg --card-status` should show the expected fingerprints and
   `UIF: Sign=on Auth=on`.

`keytocard` replaces the local secret key with a stub. For a second card, re-import the
backup into a fresh `GNUPGHOME` first, or copy the keyring before step 4.

## Extend expiry (before 2028-06-15 personal / 2028-11-05 work)

The cards don't change. Only the public cert gets new self-signatures.

```sh
gpg --quick-set-expire FE149E5D50B99EC9EE32B49507E5ACD7B3165BD3 2y '*'
gpg --armor --export 07E5ACD7B3165BD3 > pub.asc
```

Then publish the cert and refresh the backups (both below).

## Revoke the work keys (cards lost or compromised, or leaving the job)

In `gpg --edit-key`: `key 4`, `key 5`, `revkey`, `save`. Then publish and refresh the
backups. The personal keys and old signatures aren't affected. On the work Mac, delete
`~/.gitconfig.local` and the `IdentityFile` line in `~/.ssh/config.local`.

## Revoke the whole cert (primary key compromised)

`gpg --import 07E5ACD7B3165BD3-revoke.asc`, then publish. After that, create a new
cert and redo the whole setup.

## Publish the cert

```sh
# GitHub: the same primary key can't be added twice, so delete the old entry, then add the new one
gh api user/gpg_keys --jq '.[] | [.id, .key_id] | @tsv'
gh api -X DELETE user/gpg_keys/<id>
jq -n --rawfile k pub.asc '{name:"James Laska", armored_public_key:$k}' | gh api -X POST user/gpg_keys --input -
gpg --keyserver hkps://keys.openpgp.org --send-keys FE149E5D50B99EC9EE32B49507E5ACD7B3165BD3
# Each machine: re-import the public cert
curl -fsS https://github.com/jlaska.gpg | gpg --import
```

The `gh` token needs the `admin:gpg_key` and `admin:public_key` scopes
(`gh auth refresh -h github.com -s admin:gpg_key,admin:public_key`). Signatures made
before the change stay verified.

New SSH auth key: export it with `gpg --export-ssh-key <AUTH_KEYID>!`, then add it with
`gh ssh-key add <file> --type authentication`.

## Refresh backups

Export from the ceremony keyring **before** `keytocard`, into a new dated folder on the
USB stick:

```sh
gpg --armor --export-secret-keys 07E5ACD7B3165BD3 > 07E5ACD7B3165BD3-Certify.key
gpg --armor --export-secret-subkeys 07E5ACD7B3165BD3 > 07E5ACD7B3165BD3-Subkeys.key
gpg --armor --export 07E5ACD7B3165BD3 > 07E5ACD7B3165BD3-$(date +%F).asc
chmod 600 *.key
```

Then replace the Vaultwarden attachments:

- Upload the new files first: `bw create attachment --file <f> --itemid <id>`.
- Check the uploads by checksum (download one in the web vault and `sha256sum` it).
- Then delete the old attachments: `bw delete attachment <attachment-id> --itemid <id>`.

Vaultwarden adds about 50–60 bytes to each stored size, so sizes alone don't prove an
upload is intact.

## New machine

1. `git clone`, then `make install`. If SSH isn't set up yet, pull over HTTPS (see the
   troubleshooting table in SKILL.md).
2. `chmod 700 ~/.gnupg` and `chmod 600 ~/Projects/dotfiles/ssh/.ssh/*.pub`.
3. `curl -fsS https://github.com/jlaska.gpg | gpg --import`, then
   `echo FE149E5D50B99EC9EE32B49507E5ACD7B3165BD3:6: | gpg --import-ownertrust`.
4. Insert the card and run `gpg --card-status`. This creates the stubs.
5. Write `~/.ssh/config.local`. Its first line, before any `Host` block, is
   `IdentityFile ~/.ssh/id_yubikey.pub` (personal) or `~/.ssh/id_yubikey_work.pub` (work).
6. Work machine only: add `[user] signingkey = 734AE42F2DC544DF!` to `~/.gitconfig.local`.
7. Check it with the commands under "Verifying" in SKILL.md.
