# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Session Continuity

Read **`CONTINUITY.md`** at the repo root at the start of every session. It tracks the current goal, in-flight work, recent decisions and the working set of files. The ledger is gitignored (so it's per-machine), but it's the canonical session briefing — earlier chat history may have been compacted out.

Update it whenever the goal, decisions or progress state change.

## Feature context (load on demand)

`.claude/context/` holds per-feature reference docs. Load the relevant one BEFORE making changes to that feature — they capture architecture, settled trade-offs, and the file map, so you don't relitigate decisions or break invariants.

- **`.claude/context/wezterm-ai-mode.md`** — read this whenever you touch any of: `dotfiles/wezterm.lua`, `dotfiles/wezterm.sh`, `~/.config/wezterm/*`, the `wezterm` entry in `install/tools.json`, the wezterm mappings in `install/03-dotfiles.json`, the `cask:`/`tag_prefix:` extensions in `install/utils.sh`, OR the WezTerm-related blocks in `dotfiles/.zshrc` / `dotfiles/win.gitbash.bashrc` / `dotfiles/Microsoft.PowerShell_profile.ps1`.

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

`tools.json` has a `"profiles"` section (`minimal`, `dev`, `full`) mapping to tag arrays. Each tool declares an optional `"phase"` field (`"system"` for phase 01, ausente o `"tools"` para phase 02), tags (`core`, `dev`, `k8s`, `win`) for profile-based selection, and per-platform install methods. Profiles only filter `02-packages`; `01-system` siempre instala las herramientas con `phase: "system"` independientemente del profile. `nerd-fonts` es un caso especial: `auto_install: false` y se instala vía trigger desde el post_install de `lsd` (no aparece en ningún profile).

To add a new tool: add an entry to `tools.json`. The phase scripts handle the rest.

### Dotfiles

`dotfiles/` contains shell configurations copied to `$HOME`:

- `.zshrc` — Zsh config (aliases, completions, plugin-like setup)
- `.tmux.conf` — Tmux configuration
- `.tmux-ai.conf` — Tmux variant tuned for 4-pane Claude sessions (paired with WezTerm AI Mode)
- `.oh-my-posh.json` — Oh-My-Posh prompt theme (shared by all shells across all OSes)
- `Microsoft.PowerShell_profile.ps1` — PowerShell 7 profile
- `win.ps5_profile.ps1` — Windows PowerShell 5.1 profile (reduced parity; UTF-8 with BOM, do not strip)
- `win.gitbash.bashrc` — Git Bash config
- `cmd_aliases.cmd` / `clink_settings` / `oh-my-posh.lua` — CMD/Clink integration
- `wezterm.lua` — WezTerm super-config (sectioned §0-§8: customization knobs, helpers, shell choice, appearance, AI Mode, shell picker, window state, key/mouse bindings). Shipped by `03-dotfiles.json` to `~/.config/wezterm/wezterm.lua`. **Mirror policy**: every edit to `~/.config/wezterm/wezterm.lua` is also copied to `dotfiles/wezterm.lua`. Reference doc: `.claude/context/wezterm-ai-mode.md`.
- `wezterm.sh` — vendored WezTerm shell-integration helper (OSC-7 CWD + OSC-133 prompt markers). Copied to `~/.config/wezterm/wezterm.sh`; sourced by `.zshrc` / `win.gitbash.bashrc` when `WEZTERM_PANE` is set. The PowerShell profile wraps its own prompt to emit OSC-7 inline.

### Addons

`addons/windecente.ps1` — Windows 11 debloat/privacy/dev setup script (standalone).

### Research scratchpad

`tmp/` is gitignored (see `.gitignore`). Use it for cloned upstream sources you want at hand without committing, or for in-flight research notes. Currently empty — recreate ad-hoc per task and clean up when done.

## Git Commits

- **Never author commits as Claude.** The commit author must always be `LuisPalacios`. Do not add `Co-Authored-By` trailers or modify `user.name`/`user.email` in git config.
- **Never co-author commits as Claude.**
- **Never mention Claude, Claude Code, or any other AI assistant / agent / harness by name in commit messages — not in the subject, not in the body, not in trailers, not anywhere.** The commit history credits the human's work; the tooling stays invisible. If a structural reference to the `.claude/` directory is genuinely necessary for context, describe it generically (e.g., "configuración interna de tooling de desarrollo") rather than naming the AI tool. This applies recursively: do not paraphrase, hint at, or include sentences that imply AI authorship ("generated with…", "assistant produced…", emoji robots, etc.).
- Comments and commit messages in **Spanish**.

## Conventions

- **Idempotent**: all operations check before acting (e.g., `command_exists` before install)
- **Bash**: `set -euo pipefail`, logging via `log()` / `error()` / `success()` / `warning()`
- **Bash 3.2 compat is mandatory** (macOS ships Bash 3.2). NO `mapfile`, NO `declare -A`, NO `local -n`. Use `while read`, parallel arrays + lookup helpers, and eval-based array copy.
- **PowerShell**: `#Requires -Version 7.0`, PascalCase functions, `Write-Log` for output
- **Platform branching**: `case "${OS_TYPE}"` in Bash, conditional blocks in PowerShell
- **Package managers**: apt (Debian/Ubuntu), brew (macOS), scoop + winget (Windows)
- **Line endings**: `.sh`/`.zsh` → LF; `.ps1`/`.bat`/`.cmd` → CRLF (enforced by `.gitattributes`)

## Platform Quirks

- WSL2 detected via `WSL_DISTRO_NAME` env var or `/proc/version` containing "microsoft"
- Debian aliases: `batcat` → `bat`, `fdfind` → `fd` (package names differ from binary names)
- Locale setup only runs on native Linux (skipped on macOS and WSL2)
- Root user has special handling: skips interactive checks and sudo validation
