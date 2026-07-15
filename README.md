# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Quick start

```bash
git clone git@github.com:jlaska/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install.sh
```

`install.sh` installs Stow (via Homebrew) if absent, then stows every top-level package directory targeting `$HOME`.

## How it works

Each top-level directory is a **Stow package** — a logical grouping named after the tool it configures. The directory tree inside mirrors `$HOME`, so Stow knows exactly where to place the symlinks.

```
dotfiles/
  claude/               ← package name (not a dotfile path)
    .claude/
      settings.json     → ~/.claude/settings.json
      CLAUDE.md         → ~/.claude/CLAUDE.md
  zsh/                  ← (example of a future package)
    .zshrc              → ~/.zshrc
    .zprofile           → ~/.zprofile
  git/
    .gitconfig          → ~/.gitconfig
```

Running `stow --no-folding -t "$HOME" claude` creates individual file symlinks, leaving the rest of `~/.claude/` (sessions, history, cache) untouched as a real directory.

To add a new package:

```bash
mkdir -p ~/Projects/dotfiles/zsh
mv ~/.zshrc ~/Projects/dotfiles/zsh/.zshrc
cd ~/Projects/dotfiles && stow --no-folding -t "$HOME" zsh
git add zsh/ && git commit -m "Add zsh package"
```

To remove a package's symlinks without deleting files:

```bash
cd ~/Projects/dotfiles && stow --delete -t "$HOME" zsh
```

## Packages

| Package | Files managed |
|---------|--------------|
| `claude` | `~/.claude/settings.json`, `~/.claude/CLAUDE.md` |

## What is not tracked

These stay in place, unmanaged by Stow:

- `~/.claude/settings.local.json` — machine-specific Claude permission overrides; gitignored by Claude Code design
- `~/.claude/projects/`, `sessions/`, `history.jsonl`, `cache/` — runtime state, auto-generated
- `~/.claude/plugins/` — marketplace checkouts, re-downloaded on install
- `~/.claude.json` — OAuth credentials, never commit

## Design decisions

**Why GNU Stow?**
Stow is a single dependency available in every package manager. It uses ordinary symlinks — no proprietary state, no templating engine, no Go binary. Edits made at `$HOME` go directly into the repo; `git diff` always shows the truth.

Alternatives considered:

| Tool | Why not chosen |
|------|----------------|
| [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) (~31k ★) | Uses `rsync` to copy files — edits in `$HOME` silently diverge from the repo |
| [holman/dotfiles](https://github.com/holman/dotfiles) (~8k ★) | `*.symlink` naming convention requires a custom bootstrap script to maintain |
| [thoughtbot/dotfiles](https://github.com/thoughtbot/dotfiles) (~8k ★) | Requires `rcm` as an additional dependency with its own config conventions |
| [chezmoi](https://github.com/twpayne/chezmoi) (~21k ★) | Adds templating and encryption but brings its own DSL and state management — good choice if you need machine-specific templating or secrets in the repo |

**Why `--no-folding`?**
Without this flag, Stow will fold an entire directory into a single symlink when all its contents belong to one package — turning `~/.claude/` itself into a symlink. That would pull runtime state (sessions, history, cache) into the repo. `--no-folding` keeps `~/.claude/` as a real directory and creates per-file symlinks instead.

**Why `-t "$HOME"`?**
Stow defaults its target to the *parent* of the stow directory. Since the repo lives at `~/Projects/dotfiles/`, the default target would be `~/Projects/` — not `$HOME`. Explicit `-t "$HOME"` is required.
