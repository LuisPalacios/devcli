# WezTerm super-config — Claude context

**Audience**: future Claude sessions touching `wezterm.lua`, the WezTerm install path, or related shell-integration files. Read this BEFORE making changes — it captures architecture, settled trade-offs, and the file map. Don't relitigate decisions documented here without checking with the user first.

## File map

| Path | What it is |
| --- | --- |
| `dotfiles/wezterm.lua` | The super-config (~750 lines, sectioned §1-§8). **Repo is the single source of truth — edit here, never edit `~/.config/wezterm/wezterm.lua` directly.** |
| `~/.config/wezterm/wezterm.lua` | Deployment artifact written by `install/03-dotfiles.{sh,ps1}` from `dotfiles/wezterm.lua`. Treat as read-only. |
| `dotfiles/wezterm.sh` | Vendored verbatim from `tmp/wezterm/assets/shell-integration/wezterm.sh`. WezTerm's published OSC-7 + OSC-133 helper. |
| `~/.config/wezterm/window_state.json` | Runtime state (pixel size + maximized). NOT in git. Created/updated by the §6 `window-resized` handler. |
| `install/tools.json` | WezTerm install entry (`scoop` Win, `brew --cask` mac, `github-deb` Linux; tag `dev`). |
| `install/03-dotfiles.json` | Maps `wezterm.lua` + `wezterm.sh` → `~/.config/wezterm/`. |
| `install/utils.sh` | Hosts `method_brew` (with `cask:` support) and `method_github_deb` (with `tag_prefix:` support). Both extensions added for WezTerm; default behavior preserved. |
| `dotfiles/zshrc`, `dotfiles/win.gitbash.bashrc` | End-of-file `WEZTERM_PANE`-guarded source-block for `wezterm.sh`. |
| `dotfiles/Microsoft.PowerShell_profile.ps1` | Prompt wrapper after the zoxide-repair block (~line 273) emits OSC-7 when `$env:WEZTERM_PANE` is set. |
| `tmp/wezterm/` | Cloned upstream sources (gitignored). Useful for grepping the API. |
| `tmp/wezterm-research/` | Gitignored research notes from the original design phase. |

## Edit-and-test workflow

**One direction only**: edit `dotfiles/wezterm.lua`, commit + push, then re-run `bootstrap.{sh,ps1}` (or just `02-packages` + `03-dotfiles`) on the test machine to deploy. The deployed `~/.config/wezterm/wezterm.lua` is rewritten from the repo on each bootstrap, so any local hand-edit to it would be silently overwritten — don't make hand-edits to the live copy.

## `wezterm.lua` section map

| § | Purpose | Key content |
| --- | --- | --- |
| §0 | Personalización | `CUSTOMIZE` table at the very top with user-tweakable knobs. Currently exposes `CLAUDE_EXTRA_ARGS` (table of strings, default `{ '--allow-dangerously-skip-permissions' }`) — extra args spliced into every claude pane launched by AI Mode (§4), inserted **before** `--model X`. Add new knobs here as fields of `CUSTOMIZE`. The bootstrap end-of-install message (in `ux_summary` / `Show-UxSummary`) points dev/full users to this section. |
| §1 | Bootstrap & helpers | `require`, `config_builder`, `file_exists()`, `unix_command_exists()`, `exe_basename()`, forward-decls for §5 (`show_profile_picker`, `spawn_tab_same_shell`) and §6 (`apply_saved_size_to`). |
| §2 | Platform & shell choice | OS branch via `target_triple:find`. Windows: probe absolute paths (Git Bash → pwsh 7 → Windows PowerShell). Unix: probe PATH via `command -v` (zsh → bash → sh). |
| §3 | Appearance & defaults | `initial_cols/rows`, per-OS `font_size` (mac 13 / linux 12 / windows 11), `color_scheme = 'iTerm2 Dark Background'`, `scrollback_lines = 100000`, `audible_bell = 'Disabled'`, `enable_scroll_bar = true` (thumb on right edge, scales with scrollback — drag to navigate fast), `window_close_confirmation = 'NeverPrompt'`. Also hosts `show_theme_picker()` (the `CTRL+SHIFT+E` fuzzy theme picker that merges user `LP-*` schemes with bundled). |
| §4 | Feature: AI Mode | `find_claude_bin()` (path probe — see below), `AI` tunables (ratios + dedicated layout %), `pane_cwd()`, `apply_ai_mode_layout()`, `ai_mode_windows` set, `open_ai_mode()`. |
| §5 | Feature: Shell picker (Windows-only) | Hardcoded `LP-GitBash`, `LP-Campbell`, `LP-Campbell Powershell`, `LP-Ubuntu` schemes (injected into `config.color_schemes`). 6-profile picker (Git Bash, PowerShell 7, **PowerShell 7 (admin)**, Ubuntu/WSL, CMD, PowerShell 5) + last entry "Tab in this window (same shell)". The admin entry runs a launcher pwsh that calls `Start-Process wezterm-gui -Verb RunAs ... -ArgumentList 'start','--','pwsh.exe'` — UIPI prevents a non-elevated wezterm pane from hosting an elevated child, so we relaunch wezterm itself elevated (matches WT's "as administrator" pattern). `profile_by_window` map tracks who spawned each window so CTRL+ALT+T duplicates the right shell. Default `config.color_scheme` overridden via `exe_to_scheme` based on `default_prog`; existence check covers BOTH user schemes and built-ins. |
| §6 | Feature: Window state persistence | `STATE_FILE = wezterm.config_dir .. '/window_state.json'`, `read_window_state()`, `write_window_state()`, `apply_saved_size_to(mux_window)`. `window-resized` handler saves size + maximized (skips AI Mode windows by checking `ai_mode_windows`). `gui-startup` restores size, then **centers the first window** on the main screen via `wezterm.gui.screens().main`, then maximizes if the saved state was maximized. |
| §7 | Key bindings | OS-aware AI Mode modifier (`CTRL+ALT+N` Win, `CTRL+SUPER+N` mac/Linux). `CTRL+SHIFT+E` (theme picker, all OSes). Windows-only: `CTRL+SHIFT+T` (shell picker), `CTRL+ALT+T` (same-shell tab). |
| §8 | Mouse bindings | Right-click: copy if selection exists, paste otherwise (Windows Terminal style). |

## Architecture: AI Mode

```text
User presses hotkey  (CTRL+ALT+N on Windows, CTRL+SUPER+N elsewhere)
        │
        ▼
open_ai_mode(_, source_pane)
  cwd = pane_cwd(source_pane)
        ├─ pane:get_current_working_dir().file_path        (OSC 7 — best)
        ├─ pane:get_foreground_process_info().cwd          (heuristic)
        └─ wezterm.home_dir                                (last resort)
        │
        ▼
mux.spawn_window { args = { CLAUDE_BIN, '--model', 'opus' }, cwd }
  → returns (tab, tl_pane, ai_mux)
        │
        ▼
apply_ai_mode_layout(ai_mux)   ← dedicated layout, NOT saved size
  size = main_screen.{w,h} * AI.LAYOUT_{W,H}     (default 70%×80%)
  pos  = main_screen.{x,y} + main_screen.{w,h} * AI.LAYOUT_{X,Y}  (15%/10%)
ai_mode_windows[id] = true     ← mark so §6 window-resized skips it
        │
        ▼
tl:split { Right,  size = 1 - LEFT_RATIO,      args = sonnet }   → tr
tl:split { Bottom, size = 1 - LEFT_TOP_RATIO,  cwd  = cwd     }   → bl (shell)
tr:split { Bottom, size = 1 - RIGHT_TOP_RATIO, args = haiku  }   → br
tl:activate()
```

Final layout (≈ cell ratios):

```
┌─────────────────────────────┬──────────────┐
│                             │   sonnet     │
│         opus                ├──────────────┤
├─────────────────────────────┤   haiku      │
│  shell                      │              │
└─────────────────────────────┴──────────────┘
  ←─── 65% (LEFT_RATIO) ─────→ ←── 35% ─────→
   opus 82%, shell 18%          sonnet/haiku 50/50
```

### Settled design decisions for AI Mode

- **Direct-spawn**: claude is the foreground process of each pane (`args = { 'claude', '--model', X }`), no shell underneath. Sidesteps the iTerm `wait_ready` + `SEND_GAP` race. Trade-off: when claude exits, the pane closes (no shell to fall back to). Accepted.
- **`find_claude_bin()` (§4)**: macOS GUI apps launched from Finder/Spotlight inherit a minimal PATH (`/usr/bin:/bin:/usr/sbin:/sbin`) that excludes Homebrew (`/opt/homebrew/bin`) and `~/.local/bin` — so a bare `'claude'` arg fails on macOS. The probe checks known absolute paths and falls back to bare `'claude'` (works on Windows + Linux where claude is on the inherited PATH). Order: `~/.claude/local/claude`, `~/.local/bin/claude`, `/opt/homebrew/bin/claude`, `/usr/local/bin/claude`, `/usr/bin/claude`. Windows shortcuts straight to `'claude'` (the installer adds it to PATH).
- **AI Mode windows have a DEDICATED layout, not saved geometry**: `apply_ai_mode_layout()` overrides size + position to `AI.LAYOUT_{X,Y,W,H}` percentages of the main screen. The `ai_mode_windows` set tracks IDs so §6 `window-resized` skips them — resizing an AI Mode window does NOT pollute `window_state.json` for normal windows. To change the AI Mode layout, edit `AI.LAYOUT_{X,Y,W,H}` in §4 (single source).
- **Hotkey modifier is OS-aware**: `WIN+N` is grabbed by Windows Notification Center; `ALT+N` is the dead-key for `~` on macOS Spanish/US-International. Resolved with one-liner `wezterm.target_triple:find 'windows' and 'CTRL|ALT' or 'CTRL|SUPER'`.

## Settled design decisions: shell picker (§5, Windows-only)

- **Hardcoded, not WT-imported**. An earlier draft read Windows Terminal's `settings.json` to mirror profiles. Worked but tied this config to whatever state WT was in (non-idempotent — WT edits silently changed WezTerm behavior). Hardcoded list = single source of truth, identical behavior on every box.
- **New window per profile, not new tab**. WezTerm scopes `set_config_overrides` (where the per-profile `color_scheme` lives) to the GUI window, not the tab. To share one scheme across tabs instead, swap `mux.spawn_window` for `mux_window:spawn_tab` in the picker callback.
- **Color-scheme override is deferred** via `pending_scheme_by_window` + `window-focus-changed` handler, because `mux_window:gui_window()` may return nil right after spawn (GUI not realized yet). The same defer-via-`call_after` pattern is used by `apply_saved_size_to` (§6) and `apply_ai_mode_layout` (§4).
- **Default `config.color_scheme` is overridden** based on `exe_basename(config.default_prog[1])`. Existence check `scheme_exists()` covers BOTH user-injected `LP-*` schemes AND `wezterm.color.get_builtin_schemes()` — earlier version only checked user schemes, which silently failed for built-in names (default fell back to `iTerm2 Dark Background`).

## Settled design decisions: window state (§6)

- **Position cannot be persisted**. WezTerm exposes `window:set_position(x, y)` but **no getter for position**. Confirmed by reading `tmp/wezterm/docs/config/lua/window/`. Workaround: every launch's first window is **centered on the main screen** via `wezterm.gui.screens().main`. Subsequent windows pick OS-default position (Windows reopens near previous).
- **`is_full_screen` from `get_dimensions()` covers both maximized and true-fullscreen on Windows**. `gui:maximize()` is the less-aggressive restore (keeps title bar). If the user uses F11 fullscreen heavily and finds maximize wrong, swap for `toggle_fullscreen()`.
- **Saved size applies to ALL windows** (gui-startup AND picker AND AI Mode) via `apply_saved_size_to(mux_window)`. AI Mode is the exception — it uses `apply_ai_mode_layout()` instead.
- **Sanity floor**: `pixel_width > 200 AND pixel_height > 100` before applying. Defends against zero/garbage from corrupt JSON.
- **Debounced disk write (Windows-driven)**: `window-resized` does NOT write to disk synchronously. Each event bumps a generation counter, captures a snapshot, and schedules a 250 ms `wezterm.time.call_after` that only writes if no newer event has arrived. Reason: on Windows, `io.open`/`close` on `window_state.json` blocks the UI thread for 10-50 ms while Defender/AV scans the freshly written file, which manifests as visible stutter during fast drag-resize (reported 2026-04-26). macOS/Linux don't pay that cost. WezTerm's own event coalescing (1 + 1) doesn't help because the executing one is still doing the blocking I/O. The 250 ms window is invisible to the user (only the final size after they stop moving the mouse needs to land on disk) but eliminates per-frame I/O during drag.

## Cross-platform behavior matrix

| OS | Default shell | OSC 7 source | CWD detection in `pane_cwd` | Config path | claude location |
| --- | --- | --- | --- | --- | --- |
| macOS | zsh | `wezterm.sh` sourced from `.zshrc` | `Url.file_path` (POSIX) | `~/.config/wezterm/wezterm.lua` | `/opt/homebrew/bin/claude` (Apple Silicon), `/usr/local/bin/claude` (Intel) |
| Linux | zsh / bash | `wezterm.sh` sourced from rc | `Url.file_path` (POSIX) | `~/.config/wezterm/wezterm.lua` | `~/.local/bin/claude` |
| Windows / Git Bash | bash | `wezterm.sh` sourced from `.bashrc` | `Url.file_path` returns `/c/Users/…`, accepted by `chdir` as-is | `~/.config/wezterm/wezterm.lua` | `claude.exe` on PATH |
| Windows / pwsh | pwsh 7 | Inline OSC-7 prompt wrap in `$PROFILE` | `Url.file_path` returns `/C:/Users/…`, regex strips leading `/` | same | same |
| Windows / cmd.exe | cmd | none (relies on process-info fallback) | `get_foreground_process_info().cwd` | same | same |

## Installer integration map

(See `install/tools.json`, `install/03-dotfiles.json`, `install/utils.sh` for source of truth.)

```json
// tools.json — wezterm entry, tag "dev"
"linux":   { "method": "github-deb", "repo": "wezterm/wezterm",
             "version": "20240203-110809-5046fc22", "tag_prefix": "",
             "deb_pattern": "wezterm-${version}.Ubuntu22.04.deb",
             "check_cmd": "wezterm", "requires_desktop": true },
"macos":   { "method": "brew", "package": "wezterm", "cask": true },
"windows": { "method": "scoop", "package": "wezterm" }
```

**Headless Linux skip (2026-08-24)**: `requires_desktop: true` on a platform block makes `02-packages.sh` drop the tool when `IS_DESKTOP != true`. `IS_DESKTOP` is set by `detect_desktop_environment()` in `install/env.sh`: always `true` on macOS, always `false` on WSL2/other, and on Linux `true` if ANY of — `DISPLAY`/`WAYLAND_DISPLAY` set, a DE is installed (`/usr/share/{xsessions,wayland-sessions}/*.desktop`), or `systemctl get-default` is `graphical.target`. Skipped GUI tools are logged (log file only). The `ux_summary` WezTerm hint is also gated on `IS_DESKTOP`. The wezterm dotfiles (`wezterm.lua`/`wezterm.sh`) still deploy on headless Linux — harmless, and ready if the user installs WezTerm manually. PowerShell side untouched (Windows is always desktop).

```json
// 03-dotfiles.json — both files, no wsl2 (GUI app)
{ "file": "wezterm.lua", "dst": ".config/wezterm/wezterm.lua",
  "platforms": ["linux", "macos", "windows"] },
{ "file": "wezterm.sh",  "dst": ".config/wezterm/wezterm.sh",
  "platforms": ["linux", "macos", "windows"] }
```

Schema extensions made for this:

- `install/utils.sh::method_brew` — accepts optional `cask: true`. Default (formula) unchanged.
- `install/utils.sh::method_github_deb` — accepts optional `tag_prefix` (default `"v"`). WezTerm sets it to `""` because their tags lack the `v` prefix that `lsd` and most projects use.

Why these install methods (rejected alternatives):

- Windows: `scoop` over `winget` because the rest of the toolchain uses scoop and the `extras` bucket (containing wezterm) is auto-added by `bootstrap.ps1:208-245`. Precedent: `quicklook` uses identical shape.
- macOS: `brew --cask` is the standard macOS deployment path for GUI apps. No serious alternative.
- Linux: `github-deb` over a new `apt-repo` method to keep the schema diff minimal. Trade-off: updates are manual (bump `version` field).

## Trade-offs and known issues

- **`claude` not on PATH (macOS GUI launch)**: solved by `find_claude_bin()` probing absolute paths. If the user installs claude in a non-standard location, add it to the candidate list.
- **AI Mode pane closes when claude exits**: by design (no shell underneath). Rapid relaunch is two keystrokes (`CTRL+SHIFT+W` then the AI Mode hotkey).
- **`WIN+N` Notification Center collision**: WezTerm captures the keystroke first in practice; if it ever doesn't, fall back to `CTRL|SHIFT|ALT+n` or define a leader chord.
- **OSC 7 missing on cmd.exe**: falls through to `get_foreground_process_info().cwd`, which is heuristic on Windows but works in the common case.
- **Hot reload caveat**: `mux.spawn_window` callbacks reload cleanly, but if you change `config.default_prog`, existing panes keep their old shell — spawn a new pane to see it.
- **Map cleanup**: `pending_scheme_by_window`, `profile_by_window`, `ai_mode_windows` accumulate stale entries for closed windows. Memory cost is negligible at human-interaction rates; skip cleanup unless something starts complaining.
- **Multi-monitor / DPI changes**: pixel sizes saved on monitor A may look off on monitor B. No event surface in WezTerm for DPI change. Sanity floor protects against garbage; everything else is the user's call.
- **Re-sourcing PowerShell `$PROFILE` in the same session double-wraps the prompt** (the OSC-7 wrapper captures `$function:prompt` once into `$global:__wezterm_prev_prompt`; re-sourcing wraps the wrapped version). Harmless but emits two OSC-7 sequences per prompt. Restart the pwsh process to undo cleanly.

## Theme picker (§3) details

- Bound to `CTRL+SHIFT+E` cross-platform.
- Builds choices from `config.color_schemes` (LP-* user schemes injected in §5) AND `wezterm.color.get_builtin_schemes()` (~960). Dedupes by name (LP- prefix avoids collisions; dedupe is defensive).
- Sorted alphabetically (case-insensitive). Window-scoped override via `set_config_overrides`. Esc cancels (no change).
- The §3 TODO comment block has a `do…end`-wrapped snippet for previewing themes via the debug overlay (CTRL+SHIFT+L), useful when the keybinding isn't wired or for exploring the API. Important: the debug overlay treats each line as its own chunk, so locals don't survive between lines — wrap in `do…end` or omit `local`.

## When extending the file

- New features get their own §-section. The file is meant to grow this way (header banner says so).
- If the new section needs to be referenced from §7 key bindings, **forward-declare** the function as a `local` in §1 (existing examples: `show_profile_picker`, `spawn_tab_same_shell`, `apply_saved_size_to`).
- Cross-OS code goes inline; OS-specific code goes inside `if wezterm.target_triple:find 'windows' then ... end` (or `darwin`/`linux`).
- Reuse `file_exists()` and `unix_command_exists()` from §1 for any path/command probing. Don't invent new ones.
- Settle the design BEFORE editing — reading this doc, then proposing the change with trade-offs surfaced, is much cheaper than coding a flawed approach.

## Test loop

The user tests via the public path: edit `dotfiles/wezterm.lua` (or any other repo file), `git push`, then on the test machine run the full bootstrap so the changes deploy cleanly through the same path real users hit. There is no local "uninstall" helper — the bootstrap is idempotent and overwrites the deployed copy.

```bash
# On the test machine, after pushing:
# Linux / macOS / WSL2:
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)

# Windows (PowerShell 7):
iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1")
```

Smoke tests in a fresh WezTerm after the bootstrap finishes:

- `CTRL+SHIFT+R` — config reload, no Lua errors (`CTRL+SHIFT+L` for debug overlay).
- `CTRL+SHIFT+T` (Windows) — shell picker → 5 profiles + "Tab in this window (same shell)".
- `CTRL+ALT+T` (Windows) — same-shell tab.
- AI Mode hotkey (`CTRL+ALT+N` Win, `CTRL+SUPER+N` mac/Linux) — 4-pane window at the dedicated layout.
- `CTRL+SHIFT+E` — theme picker (LP-* + bundled).
- drag-resize a normal window → close → reopen → restored size, centered on main screen.

## References

- WezTerm upstream: <https://wezterm.org/>
- WezTerm source repo: <https://github.com/wezterm/wezterm>
- Color scheme gallery: <https://wezterm.org/colorschemes>
- Cloned source for grepping API: `tmp/wezterm/` (gitignored)
- Original research notes: `tmp/wezterm-research/` (gitignored)
- iTerm prior art for AI Mode: ["iTerm in AI Mode"](https://luispa.com/posts/2026-04-25-iterm-modo-ia/) and `~/Library/Application Support/iTerm2/Scripts/AutoLaunch/aimode.py`
