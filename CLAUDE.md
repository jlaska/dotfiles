# dotfiles

GNU Stow dotfiles for a Fedora workstation (personal) and a macOS work laptop. See
[README.md](README.md) for the package layout and `make` targets.

- Every top-level directory without a leading dot is a stow package, and `make install`
  stows it. Packages ending in `-darwin` or `-linux` are stowed only on that OS. Put
  repo-only material in a dot-directory.
- Machine-specific settings go in untracked `*.local` files (`~/.gitconfig.local`,
  `~/.ssh/config.local`). Never commit secrets: pre-commit runs detect-secrets and
  gitleaks.
- The repo is **public**. Keep YubiKey serials, hostnames and IP addresses, and
  Vaultwarden item names out of it.
- Commit messages follow `type(scope): Summary` (for example `fix(ssh): ...`), and
  commits are GPG-signed.
- **YubiKey, GPG, SSH-agent or commit-signing work:** use the `yubikey-operations` skill
  (`claude/.claude/skills/yubikey-operations/`, stowed to `~/.claude/skills/` by `make install`).
