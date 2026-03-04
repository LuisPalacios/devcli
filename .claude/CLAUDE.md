# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**devcli** is a cross-platform CLI environment provisioning tool. It automates the setup of a unified shell experience (prompt, aliases, tools) across Linux (Debian/Ubuntu), macOS, WSL2, and Windows 11. Written in Bash and PowerShell 7 — no compiled code, no build system.

Documentation and comments are in **Spanish**.

## Running

```bash
# Linux / macOS / WSL2
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)
# With custom locale:
bash <(curl -fsSL ...bootstrap.sh) -l en_US.UTF-8

# Windows (PowerShell 7)
iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1")
```

There is no build step, test suite, or linter configured for this project.

## Architecture

### Bootstrap → Phased Pipeline

`bootstrap.{sh|ps1}` is the entry point. It clones the repo to `~/.devcli`, then runs numbered phase scripts sequentially:

```
bootstrap.{sh|ps1}
  └─ install/env.{sh|ps1}       ← OS detection, user, paths, locale
  └─ install/utils.{sh|ps1}     ← Shared helpers (logging, package install, font setup)
  └─ install/01-system.{sh|ps1} ← Base system: permissions, ~/bin directory
  └─ install/02-packages.{sh|ps1} ← Package manager tools (apt/brew/scoop)
  └─ install/03-dotfiles.{sh|ps1} ← Copy shell configs to $HOME
  └─ install/04-gitfiles.{sh|ps1} ← Clone external Git utility repos
  └─ install/05-localtools.{sh|ps1} ← Local scripts + Nerd Font install
```

Each phase has paired `.sh` (Unix) and `.ps1` (Windows) implementations. Phase scripts source `env` + `utils` at the top.

### Configuration-Driven

Phases 01–05 read JSON config files that declare *what* to install; the scripts implement *how*:

| Config | Purpose |
|--------|---------|
| `install/tools.json` | **Single source of truth** for all installable tools (tags, methods, platforms, profiles) |
| `install/03-dotfiles.json` | Dotfile → destination mappings (platform-filtered) |
| `install/04-gitfiles.json` | External Git repos to clone |
| `install/05-localtools.json` | Local helper scripts to install (platform-filtered) |

`tools.json` has a `"profiles"` section (`minimal`, `dev`, `full`) mapping to tag arrays. Each tool declares tags (`system`, `core`, `dev`, `k8s`, `win`, `fonts`) and per-platform install methods. Profiles only filter `02-packages`; `01-system` always installs all `system`-tagged tools.

To add a new tool: add an entry to `tools.json`. The phase scripts handle the rest.

### Dotfiles

`dotfiles/` contains shell configurations copied to `$HOME`:
- `.zshrc` — Zsh config (aliases, completions, plugin-like setup)
- `.tmux.conf` — Tmux configuration
- `.oh-my-posh.json` — Oh-My-Posh prompt theme
- `Microsoft.PowerShell_profile.ps1` — PowerShell 7 profile
- `win.gitbash.bashrc` — Git Bash config
- `cmd_aliases.cmd` / `clink_settings` / `oh-my-posh.lua` — CMD/Clink integration

### Addons

`addons/windecente.ps1` — Windows 11 debloat/privacy/dev setup script (standalone).

## Git Commits

- **Never author commits as Claude.** The commit author must always be `LuisPalacios`. Do not add `Co-Authored-By` trailers or modify `user.name`/`user.email` in git config.
- Comments and commit messages in **Spanish**.

## Conventions

- **Idempotent**: all operations check before acting (e.g., `command_exists` before install)
- **Bash**: `set -euo pipefail`, logging via `log()` / `error()` / `success()` / `warning()`
- **PowerShell**: `#Requires -Version 7.0`, PascalCase functions, `Write-Log` for output
- **Platform branching**: `case "${OS_TYPE}"` in Bash, conditional blocks in PowerShell
- **Package managers**: apt (Debian/Ubuntu), brew (macOS), scoop + winget (Windows)
- **Line endings**: `.sh`/`.zsh` → LF; `.ps1`/`.bat`/`.cmd` → CRLF (enforced by `.gitattributes`)

## Platform Quirks

- WSL2 detected via `WSL_DISTRO_NAME` env var or `/proc/version` containing "microsoft"
- Debian aliases: `batcat` → `bat`, `fdfind` → `fd` (package names differ from binary names)
- Locale setup only runs on native Linux (skipped on macOS and WSL2)
- Root user has special handling: skips interactive checks and sudo validation
