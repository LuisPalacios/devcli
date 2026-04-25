Last updated: 2026-04-25

## Goal (incl. success criteria)

Four follow-ups queued for the next session:

1. **Ship WezTerm via devcli** — implement the installer phase per `docs/wezterm-ai-mode.md` §7.
   Success: `bootstrap.sh` / `bootstrap.ps1` on a fresh box produces a working WezTerm with the same `~/.config/wezterm/wezterm.lua` we have today; AI Mode + shell picker work without manual steps.
2. **Git Bash performance triage** — investigate why the user's Git Bash session feels slow.
   Success: a written diagnosis (startup vs prompt vs subshell, where the time goes) plus at least one concrete mitigation.
3. **Architecture review of devcli** — full read-through with prioritised improvement recommendations.
   Success: a structured report (per-area: bootstrap, install/, dotfiles/, addons/) calling out friction, dead code, missing abstractions, and the top 3-5 changes that would pay off most.
4. **Evaluate `eza` as a successor to `lsd`** — modern Rust replacement for `lsd` (which itself replaced GNU `ls` aliases). Tentative — pending a side-by-side comparison.
   Success: decision recorded (keep `lsd`, switch to `eza`, or run both); if "switch", `tools.json` + dotfile aliases updated and a clean migration path documented.

## Constraints/Assumptions

- Comments and commit messages in **Spanish**. Never author or co-author commits as Claude (`user.name`/`user.email` stay `LuisPalacios`).
- **Mirror policy** for wezterm.lua: every edit to `~/.config/wezterm/wezterm.lua` is also copied to `dotfiles/wezterm.lua` in this repo. Captured as a feedback memory.
- Cross-platform: paired `.sh` + `.ps1`; phases are numbered and idempotent (`command_exists` before installing).
- `install/tools.json` is the single source of truth for installable tools; profiles `minimal` / `dev` / `full` filter via tags.
- Line endings enforced by `.gitattributes` (`.sh` LF, `.ps1` CRLF).
- WSL distro for the Ubuntu profile is hardcoded as `Ubuntu-24.04` — works on this user's box but **UNCONFIRMED** for other machines.

## Key decisions

- WezTerm config is one file for three OSes. Sectioned (§1-§7) so future features land in their own block.
- `§5` shell picker is **hardcoded** (not reading WT's settings.json) for idempotency. WT-import path was tried, abandoned; kept as reference in `tmp/wezterm-research/06-wt-import.md`.
- Per-profile colors require **new windows** per profile (`set_config_overrides` is window-scoped, not tab-scoped). Trade-off accepted.
- AI Mode hotkey is OS-aware: `CTRL|ALT+n` on Windows (`WIN+n` collides with Notification Center), `CTRL|SUPER+n` elsewhere (`ALT+n` is dead-key `~` on macOS).
- Direct-spawn for AI Mode (claude is the pane's foreground process — no shell layer, no `send_text` race). Pane closes when claude exits — accepted.
- Color-scheme override is deferred via `window-focus-changed` when `mux_window:gui_window()` returns nil right after spawn.

## State

### Done

- `~/.config/wezterm/wezterm.lua` written, tested on Windows 11 (Git Bash default + 5-profile picker + AI Mode + WT-style right-click + close-without-prompt). Mirrored to `dotfiles/wezterm.lua`.
- `docs/wezterm-ai-mode.md` — internal context doc, has §7 installer checklist ready to execute.
- `tmp/wezterm-research/00..06-*.md` + `wezterm-ai-mode-public.md` — research scratchpad (gitignored).
- Schemes hardcoded: `GitBash`, `Campbell`, `Campbell Powershell`, `Ubuntu`.
- TODO comment block in §3 of wezterm.lua listing ~960 bundled themes + the previews URL.

### Now

Nothing in flight. Session paused.

### Next

1. WezTerm installer phase (`tools.json` entry, dotfile mappings, OSC-7 line in shell rc dotfiles).
2. Git Bash perf triage (need user to describe symptom first).
3. Architecture review (need user to confirm scope: doc only vs PRs).
4. eza vs lsd decision — short benchmark + UX comparison, then either keep `lsd` or replace it (and decide whether to keep both during a transition).

## Open questions (UNCONFIRMED)

- WezTerm phase number? Reuse `02-packages` or new `06-wezterm`?
- Ubuntu WSL distro hardcode (`Ubuntu-24.04`) — should the picker auto-detect via `wsl --list --quiet` instead, or stay hardcoded for determinism?
- Git Bash perf — what's the actual symptom? slow first prompt, slow subshells, slow `git status`, all of the above?
- Architecture review — single deliverable doc, or multiple PRs? Severity threshold?
- eza vs lsd — keep both behind an alias toggle, or hard-replace? Affects whether we drop `lsd` from `tools.json` or just demote its tag.

## Working set (files/ids/commands)

- `~/.config/wezterm/wezterm.lua` — working copy (~520 lines, sectioned §1-§7).
- `dotfiles/wezterm.lua` — repo mirror (must stay byte-identical to working copy).
- `docs/wezterm-ai-mode.md` — internal doc, **§7 = the installer checklist**.
- `tmp/wezterm-research/` — gitignored notes; `06-wt-import.md` has the per-profile + scheme details.
- `install/tools.json` — needs wezterm entry next session.
- `install/03-dotfiles.json` — needs `wezterm.lua` → `~/.config/wezterm/wezterm.lua` mapping.
- `dotfiles/.zshrc`, `dotfiles/win.gitbash.bashrc`, `dotfiles/Microsoft.PowerShell_profile.ps1` — need WEZTERM_PANE-guarded OSC-7 emitter.
- `~/.claude/projects/.../memory/MEMORY.md` — auto-memory index; has `feedback_wezterm_dotfile_mirror.md` entry.

Mirror command (run after every wezterm.lua edit):

```sh
cp "$HOME/.config/wezterm/wezterm.lua" "$REPO/dotfiles/wezterm.lua"
```

Smoke-test entry points: `CTRL+SHIFT+L` (debug overlay), `CTRL+SHIFT+R` (force config reload), `CTRL+SHIFT+T` (shell picker), `CTRL+ALT+N` (AI Mode on Windows).
