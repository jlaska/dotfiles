# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Quick start

```bash
git clone git@github.com:jlaska/dotfiles.git
cd dotfiles
make install  # bootstraps xcode-select + Homebrew, stows all packages, installs Brewfile
```

## Packages

| Package | Files managed |
|---------|--------------|
| [Ansible](https://docs.ansible.com/) | `~/.ansible.cfg` |
| [AWS CLI](https://aws.amazon.com/cli/) | `~/.aws/config` |
| [Homebrew](https://brew.sh/) | `~/Brewfile` |
| [Claude Code](https://github.com/anthropics/claude-code) | `~/.claude/settings.json`, `~/.claude/CLAUDE.md` |
| [Containers](https://github.com/containers/common) | `~/.config/containers/registries.conf` |
| [Finicky](https://github.com/johnste/finicky) | `~/.finicky.js` |
| [Git](https://git-scm.com/) | `~/.gitconfig`, `~/.gitconfig-redhat`, `~/.config/git/ignore` |
| [GitHub CLI](https://cli.github.com/) | `~/.config/gh/config.yml` |
| [GnuPG](https://gnupg.org/) | `~/.gnupg/{gpg,gpg-agent,dirmngr,scdaemon}.conf` |
| [LDAP](https://www.openldap.org/) | `~/.ldaprc` |
| [npm](https://www.npmjs.com/) | `~/.npmrc` |
| [SSH](https://www.openssh.com/) | `~/.ssh/config`, `~/.ssh/id_yubikey.pub` |
| [Vim](https://www.vim.org/) | `~/.vimrc`, `~/.vim/init/*.vim`, `~/.vim/spell/en.utf-8.add` |
| [Zsh / Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) | `~/.zshrc`, `~/.oh-my-zsh/custom/{aliases,claude,jira,path,prompt,safe-chain,sops,yubikey}.zsh` |

> **Oh My Zsh plugin prerequisites** — the following must be cloned once per machine (`make install-omz-plugins` handles this):
>
> - [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
> - [zsh-completions](https://github.com/zsh-users/zsh-completions)
> - [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)

<!-- -->

> **Vim plugin prerequisites** — plugins use vim's native package system (`~/.vim/pack/`). The following are cloned once per machine (`make install-vim-plugins` handles this):
>
> - [ansible-vim](https://github.com/pearofducks/ansible-vim)
> - [ctrlp.vim](https://github.com/kien/ctrlp.vim)
> - [editorconfig-vim](https://github.com/editorconfig/editorconfig-vim)
> - [flake8-vim](https://github.com/andviro/flake8-vim)
> - [syntastic](https://github.com/scrooloose/syntastic)
> - [vim-base64](https://github.com/christianrondeau/vim-base64)
> - [vim-fugitive](https://github.com/tpope/vim-fugitive)
> - [vim-gnupg](https://github.com/jamessan/vim-gnupg)
> - [vim-markdown](https://github.com/plasticboy/vim-markdown)
> - [vim-python-pep8-indent](https://github.com/hynek/vim-python-pep8-indent)

## New machine setup (keys)

Private key material is never committed. It lives in Vaultwarden and is copied into the
macOS Keychain on each machine, where shell config and `make import-keys` read it with
`security find-generic-password -s <item> -a "$USER" -w`.

YubiKey-resident keys (signing, encryption, SSH auth) need no backup; `gpg --card-status`
recreates the local stubs. There are two YubiKeys holding the same subkeys — primary
(5C Nano, serial 38083705) and a backup. After switching cards, run `yk-switch` (alias in
`yubikey.zsh`) so the stubs point at the inserted card. The offline certify (primary) key
`FE149E5D50B99EC9EE32B49507E5ACD7B3165BD3` is stored separately and is not on this machine. The public key is fetched from
`https://github.com/jlaska.gpg`.

| Keychain item (`-s`) | Contents (single-line base64) |
|----------------------|-------------------------------|
| `gpg-sops-key` | `gpg --export-secret-keys --armor 8668024533C807BFAC0246A3339F4E72487C358F` (SOPS key) |
| `gpg-argocd-secrets-key` | `gpg --export-secret-keys --armor 319C4CA1B91B7147BD6B38155DB5F1A4459A1F71` (k3s.keener.cluster) |
| `gpg-ownertrust` | `gpg --export-ownertrust` |
| `sops-age-key` | `~/.config/sops/age/keys.txt` |

```bash
# Populate Keychain from Vaultwarden (repeat per item), then:
security add-generic-password -U -s gpg-sops-key -a "$USER" -w "<base64 from Vaultwarden>"
make import-keys
ssh-add -L                     # should list cardno:38_083_705
git commit --allow-empty -m t  # should prompt for YubiKey PIN
```

## How it works

Each top-level directory is a **Stow package** — a logical grouping named after the tool it configures. The directory tree inside mirrors `$HOME`, so Stow knows exactly where to place the symlinks.

```text
dotfiles/
  claude/                          ← package name (not a dotfile path)
    .claude/
      settings.json                → ~/.claude/settings.json
      CLAUDE.md                    → ~/.claude/CLAUDE.md
  zsh/
    .zshrc                         → ~/.zshrc
    .oh-my-zsh/
      custom/
        aliases.zsh                → ~/.oh-my-zsh/custom/aliases.zsh
        path.zsh                   → ~/.oh-my-zsh/custom/path.zsh
        (etc.)
```

Running `stow --no-folding -t "$HOME" claude` creates individual file symlinks, leaving the rest of `~/.claude/` (sessions, history, cache) untouched as a real directory.

To add a new package:

```bash
mkdir -p zsh
mv ~/.zshrc zsh/.zshrc
stow --no-folding -t "$HOME" zsh
git add zsh
git commit -m "Add zsh package"
```

To remove a package's symlinks without deleting files:

```bash
stow --delete -t "$HOME" zsh
```

## What is not tracked

Files fall into four categories that are intentionally excluded from this repo:

**Credentials and secrets** — OAuth tokens, API keys, private keys, and certificates. Blocked by `.gitignore` filename patterns and caught by the `detect-secrets` pre-commit hook regardless of filename.

**Machine-local overrides** — Files with `.local` or `.local.json` suffixes used by tools for per-machine configuration that should not roam across machines. Claude Code's `settings.local.json` is a canonical example.

**Runtime and application state** — Session data, command history, caches, lock files, and logs generated by running applications. These change constantly and are meaningless outside the machine that produced them.

**Auto-provisioned content** — Plugin marketplaces, package manager downloads, and anything re-fetched automatically on install. Re-created by `make install` or the applications themselves; storing them here would be redundant and noisy.
