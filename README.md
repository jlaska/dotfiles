# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## TL;DR

- `make install` stows every top-level package (`-darwin` / `-linux` packages only on that OS).
- Per-machine settings live in untracked `*.local` files. Secrets never land here.
- **YubiKeys:** one GPG cert (`0x07E5ACD7B3165BD3`), one GitHub identity, and two key
  pairs. The personal pair is used on Fedora, and the work pair on the work Mac. The
  procedures and troubleshooting are in the Claude skill
  [`yubikey-operations`](claude/.claude/skills/yubikey-operations/SKILL.md) (stowed to `~/.claude/skills/`, so it works in any directory).
- Claude Code context for this repo: [CLAUDE.md](CLAUDE.md).

## Quick start

```bash
git clone git@github.com:jlaska/dotfiles.git
cd dotfiles
make bootstrap          # Xcode CLT, Homebrew, stow, pre-commit (also run by `make install`)
make install            # bootstraps if needed, then stows all packages
make install-brewfile   # core Brewfile (optional profiles: see Homebrew profiles)
```

## Packages

| Package | Files managed |
|---------|--------------|
| [Ansible](https://docs.ansible.com/) | `~/.ansible.cfg` |
| [AWS CLI](https://aws.amazon.com/cli/) | `~/.aws/config` |
| [rsync](https://rsync.samba.org/) backup | `~/.config/backup/excludes.txt` |
| [Homebrew](https://brew.sh/) | `~/Brewfile` (core) and `~/Brewfile.<profile>` (optional, see [Homebrew profiles](#homebrew-profiles)) |
| [Claude Code](https://github.com/anthropics/claude-code) | `~/.claude/settings.json` (shared by all machines), `~/.claude/CLAUDE.md`, `~/.claude/skills/yubikey-operations/`, `~/.claude/mcp/<server>.json` (opt-in MCP servers: `claude-mcp github`, or copy into a project's `.mcp.json`). Backend per invocation: `claude`, `claude-api`, `claude-litellm` in `claude.zsh` |
| [Containers](https://github.com/containers/common) | `~/.config/containers/registries.conf` |
| [Docker](https://docs.docker.com/reference/cli/docker/) credential store | `~/.docker/config.json` `credsStore` only, merged by `make install-docker-config` (not stowed) |
| [Finicky](https://github.com/johnste/finicky) | `~/.finicky.js` |
| [Git](https://git-scm.com/) | `~/.gitconfig` (includes untracked `~/.gitconfig.local`), `~/.config/git/ignore` |
| [GitHub CLI](https://cli.github.com/) | `~/.config/gh/config.yml` |
| [GnuPG](https://gnupg.org/) | `~/.gnupg/{gpg,dirmngr}.conf`; `~/.gnupg/{gpg-agent,scdaemon}.conf` from `gnupg-darwin` / `gnupg-linux` |
| [LDAP](https://www.openldap.org/) | `~/.ldaprc` |
| [mise](https://mise.jdx.dev/) | `~/.config/mise/config.toml` (runtimes and CLI tools, incl. the Linux `docker-credential-secretservice` helper; `make install-mise`) |
| [npm](https://www.npmjs.com/) | `~/.npmrc` |
| [OpenCode](https://opencode.ai/) | `~/.config/opencode/opencode.jsonc` |
| [SSH](https://www.openssh.com/) | `~/.ssh/config` (includes untracked `~/.ssh/config.local`), `~/.ssh/id_yubikey.pub`, `~/.ssh/id_yubikey_work.pub` |
| [Vim](https://www.vim.org/) | `~/.vimrc`, `~/.vim/init/*.vim`, `~/.vim/spell/en.utf-8.add` |
| [xremap](https://github.com/xremap/xremap) (Linux) | `~/.config/xremap/config.yml`, `~/.config/systemd/user/xremap.service` |
| [Zsh / Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) | `~/.zshrc`, `~/.zshenv`, `~/.oh-my-zsh/custom/{aliases,claude,jira,path,prompt,safe-chain,sops,yubikey,zz-mise}.zsh` |

Packages suffixed `-darwin` or `-linux` are only stowed on the matching OS (`uname -s`).

> **Oh My Zsh plugin prerequisites** — the following must be cloned once per machine (`make install-omz-plugins` handles this):
>
> - [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
> - [zsh-completions](https://github.com/zsh-users/zsh-completions)
> - [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)

<!-- -->

> **Docker credential helper** — `~/.docker/config.json` is deliberately not a stow package: the docker CLI and Docker Desktop rewrite it (replacing any symlink) and it can hold registry auth, so `make install-docker-config` uses `jq` to set only `credsStore` and leave everything else alone. Linux sets `secretservice` (helper installed by mise; needs a running Secret Service such as GNOME Keyring). macOS keeps an existing `desktop` value, otherwise sets `osxkeychain` (brew `docker-credential-helper`). Podman's own auth (`~/.config/containers/auth.json`) is not managed.

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

## Homebrew profiles

`make install-brewfile` installs only the core `brew/Brewfile`: the tools
the dotfiles themselves depend on (git, GPG, YubiKey, stow, uv, pre-commit, ripgrep, jq and so on).
Everything else is an opt-in profile in `brew/Brewfile.<name>`:

| Profile | Contents |
|---------|----------|
| `ai` | AI agent CLIs (gemini-cli, opencode, promptfoo, ...) and npm/uv tools. The `nvidia/openshell` tap needs `gh auth login`, and the npm entries need `~/.npm-global` to exist |
| `cloud` | awscli, aws-nuke, cloudflared, rclone, b2, minio-mc, storj, rosa, checkov |
| `dev` | go, rust, python 3.11/3.12, ruff, golangci-lint, goreleaser, pnpm, ansible, postgresql |
| `extras` | nmap, mutt, putty, archive tools, esptool, mosquitto and other utilities |
| `k8s` | kubectl plugins, k9s, kind, minikube, podman (+ qemu), talos, trivy and friends |
| `media` | imagemagick, pandoc, poppler, potrace, qrencode, and the blackhole/buzz casks |

```bash
make install-brew                       # install Homebrew itself (if missing); `make bootstrap` does this
make install-brewfile                   # core Brewfile only
make install-brewfile-<name>            # one profile only (no core), e.g. make install-brewfile-dev
make install-brewfile install-brewfile-k8s install-brewfile-ai   # core plus several profiles
make help                               # lists the available profile names
```

`install-brewfile*` targets never install Homebrew; without `brew` they fail with a hint to run
`make install-brew`.

Taps live in the profile that needs them. Profiles are discovered from `brew/Brewfile.*`, so a
new file is picked up automatically (its first line is the description shown by `make help`).
`make brew-dump` writes to a temporary file rather than overwriting `brew/Brewfile`; sort new
entries into the right profile by hand.

## New machine setup (keys)

Private key material is never committed. It lives in Vaultwarden and is copied into the
macOS Keychain on each machine, where shell config and `make import-keys` read it with
`security find-generic-password -s <item> -a "$USER" -w`.

YubiKey-resident keys (signing, encryption, SSH auth) need no backup; `gpg --card-status`
recreates the local stubs. Each pair (personal, work) is two YubiKeys holding the same
subkeys. After switching cards within a pair, run `yk-switch` (alias in `yubikey.zsh`) so
the stubs point at the inserted card. The offline certify (primary) key
`FE149E5D50B99EC9EE32B49507E5ACD7B3165BD3` is stored separately and is not on this machine.
The public key is fetched from `https://github.com/jlaska.gpg`. For per-machine SSH and
git signing setup, see the `yubikey-operations` skill's
[procedures](claude/.claude/skills/yubikey-operations/references/procedures.md#new-machine).

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
ssh-add -L                     # should list a cardno: key (this machine's pair)
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
