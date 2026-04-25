# WezTerm Super-Config — Internal Context

> **Audience**: future Claude sessions, future-me, anyone working on a devcli phase that ships WezTerm. **Not** an end-user how-to (that lives in the blog post). This document captures the architecture, the config it depends on, the shell integration it expects, and the explicit checklist for porting it into devcli.

## 1. Purpose & status

The `wezterm.lua` shipped with this project is **the long-term home for Luis's terminal config across macOS, Linux and Windows** — one source file, three OSes, designed to grow over time. Today it covers:

- Smart shell selection per OS with cascade fallbacks (Git Bash → pwsh 7 → Windows PowerShell on Windows; zsh → bash → sh on Unix).
- Cross-platform appearance/behavior defaults (font, color scheme, scrollback, audible bell).
- **AI Mode** — a one-keystroke workflow: a hotkey (see §3.3 for per-OS modifier) from any WezTerm pane opens a new window split into four panes (opus / sonnet / haiku / shell) all anchored to the directory the hotkey was pressed from. Ports the iTerm2 setup at `~/Library/Application Support/iTerm2/Scripts/AutoLaunch/aimode.py` (post: ["iTerm in AI Mode"](https://luispa.com/posts/2026-04-25-iterm-modo-ia/)).
- **Shell profile picker (Windows-only)** — a hardcoded, idempotent list of shell profiles (Git Bash, PowerShell 7, Ubuntu, CMD, PowerShell 5). Clicking the "+" tab button or pressing `CTRL+SHIFT+T` shows a fuzzy picker; the chosen profile opens in a **new window** with that profile's color scheme applied. See §3.5.
- Windows-Terminal-style mouse copy/paste (right-click copies if text is selected, pastes otherwise).

### Repository mirror

The working copy lives at `~/.config/wezterm/wezterm.lua`. After every change to that file during this research phase, the same content is mirrored to `dotfiles/wezterm.lua` in this repo so:

- The repo always holds a backup of the latest tested config.
- The future devcli installer phase can ship `dotfiles/wezterm.lua` → `~/.config/wezterm/wezterm.lua` without further reverse-engineering.

**Targets**: macOS, Linux, Windows. Single `wezterm.lua` source for all three.

**Status**: research artifact, not yet wired into devcli phases. The config is hand-installed at `~/.config/wezterm/wezterm.lua` for testing. See §7 for the explicit port plan. The AI Mode feature is the headline use case driving the research, but the file structure is sectioned (§1–§5) so future hotkeys/features land in their own block instead of bloating an existing one.

## 2. Architecture

```text
┌──────────────────────┐
│ User presses hotkey  │  CTRL+SUPER+N from any pane in any WezTerm window
└──────────┬───────────┘
           ▼
┌──────────────────────────────────────────────────────────────┐
│ wezterm.action_callback(open_ai_mode)                        │
│   pane_cwd(source_pane)                                       │
│      → pane:get_current_working_dir().file_path  (OSC 7)      │
│      → pane:get_foreground_process_info().cwd    (fallback)   │
│      → wezterm.home_dir                          (last resort)│
└──────────┬───────────────────────────────────────────────────┘
           ▼
┌──────────────────────────────────────────────────────────────┐
│ wezterm.mux.spawn_window{ args=claude_args('opus'), cwd=cwd } │
│   returns (tab, tl_pane, window) — opus is the initial pane   │
└──────────┬───────────────────────────────────────────────────┘
           ▼
┌──────────────────────────────────────────────────────────────┐
│ tl_pane:split{ direction='Right', size=0.35, args=…, cwd=cwd}│  → tr (sonnet)
│ tl_pane:split{ direction='Bottom', size=0.18, cwd=cwd }      │  → bl (shell)
│ tr_pane:split{ direction='Bottom', size=0.50, args=…, cwd=cwd}│  → br (haiku)
└──────────────────────────────────────────────────────────────┘

Final layout (approximate cell ratios):
┌─────────────────────────────┬──────────────┐
│                             │   sonnet     │
│         opus                ├──────────────┤
├─────────────────────────────┤   haiku      │
│  shell                      │              │
└─────────────────────────────┴──────────────┘
  ←─── 65% (LEFT_RATIO) ─────→ ←── 35% ─────→
   opus 82%, shell 18%          sonnet/haiku 50/50
```

Key design choice: **claude is the foreground process of each pane** (via `args = { 'claude', '--model', X }`). No shell underneath. This sidesteps the "shell init race" that the iTerm Python script defends against with `wait_ready()` + `SEND_GAP`. Trade-off: when claude exits the pane closes (no shell to fall back to). See §6.

## 3. The config

Lives at `~/.config/wezterm/wezterm.lua` (or `%USERPROFILE%\.wezterm.lua` on Windows). Single file, all three OSes. The file is organized into five clearly-labelled sections (§1–§5) so adding a future feature (e.g. a "Quake mode" overlay, an SSH-multiplex hotkey) is a copy of §4, not a rewrite.

### Section map

| Section | Purpose |
| --- | --- |
| §1 Bootstrap & helpers | `require`, `config_builder`, two helpers: `file_exists(path)` and `unix_command_exists(cmd)`. Helpers are file-scoped so any later section can use them. |
| §2 Platform & shell choice | OS branch via `target_triple:find`. Each branch picks the best available shell with a fallback cascade — see §3.1. |
| §3 Appearance & defaults | `initial_cols/rows`, `font_size`, `color_scheme`, `scrollback_lines`, `audible_bell`, `window_close_confirmation = 'NeverPrompt'` (no "Really kill this window?" prompt). |
| §4 Feature: AI Mode | The four-pane Claude workspace. Self-contained: `AI` tunables table, `pane_cwd()` helper, `open_ai_mode()` builder. |
| §5 Feature: Shell picker | (Windows-only) Hardcoded list of 5 shell profiles (Git Bash, PowerShell 7, Ubuntu/WSL, CMD, PowerShell 5) and 4 schemes (GitBash, Campbell, Campbell Powershell, Ubuntu). A fuzzy `InputSelector` picker is bound to the "+" button click and `CTRL+SHIFT+T`; each pick spawns a new window with the profile's `color_scheme` applied via `mux_window:gui_window():set_config_overrides`. See §3.5. |
| §6 Key bindings | `config.keys` registry. AI Mode binding picks an OS-aware modifier (§3.3). On Windows, the WT picker hotkey is appended. Future feature hotkeys land here too. |
| §7 Mouse bindings | `config.mouse_bindings`. Windows-Terminal-style right-click: copy if a selection exists, paste otherwise. |

### 3.1 Shell-detection cascade

```lua
-- Windows: probe absolute paths via os.getenv + file_exists
if wezterm.target_triple:find 'windows' then
  local prog_files = os.getenv('ProgramFiles') or 'C:\\Program Files'
  local sys_root   = os.getenv('SystemRoot')   or 'C:\\Windows'
  local git_bash   = prog_files .. '\\Git\\bin\\bash.exe'
  local pwsh_7     = prog_files .. '\\PowerShell\\7\\pwsh.exe'
  local win_ps     = sys_root   .. '\\System32\\WindowsPowerShell\\v1.0\\powershell.exe'
  if     file_exists(git_bash) then config.default_prog = { git_bash, '-l', '-i' }
  elseif file_exists(pwsh_7)   then config.default_prog = { pwsh_7,   '-NoLogo' }
  else                              config.default_prog = { win_ps,   '-NoLogo' } end

-- Unix: probe PATH via `command -v` (only safe on the unix branch)
elseif wezterm.target_triple:find 'darwin' or wezterm.target_triple:find 'linux' then
  if     unix_command_exists('zsh')  then config.default_prog = { 'zsh',  '-l' }
  elseif unix_command_exists('bash') then config.default_prog = { 'bash', '-l' }
  else                                    config.default_prog = { 'sh',   '-l' } end
end
```

Why both helpers: Windows shells are at known absolute paths (`Program Files`, `System32`) so probing the filesystem is precise. Unix shells live on `PATH` so `command -v` is the right idiom. `unix_command_exists` is **never** called on Windows — `io.popen` would dispatch to `cmd.exe` which doesn't have `command -v`.

### 3.2 AI Mode feature (§4 of the file)

```lua
-- Tunables (carry over verbatim from the iTerm aimode.py).
local AI = {
  LEFT_RATIO       = 0.65,  -- opus column width
  LEFT_TOP_RATIO   = 0.82,  -- opus share of left column
  RIGHT_TOP_RATIO  = 0.50,  -- sonnet vs haiku
  MODELS = { tl = 'opus', tr = 'sonnet', br = 'haiku' },
  CLAUDE_BIN = 'claude',
}

-- Resolves the CWD: OSC 7 → process info → home dir.
local function pane_cwd(pane)
  local url = pane:get_current_working_dir()
  if url and url.file_path then
    local p = url.file_path
    if wezterm.target_triple:find 'windows' then
      p = p:gsub('^/([A-Za-z]:)', '%1')   -- /C:/… → C:/…
    end
    return p
  end
  local info = pane:get_foreground_process_info()
  if info and info.cwd and info.cwd ~= '' then return info.cwd end
  return wezterm.home_dir
end

local function open_ai_mode(_, source_pane)
  local cwd = pane_cwd(source_pane)
  local claude_args = function(m) return { AI.CLAUDE_BIN, '--model', m } end

  local _, tl = mux.spawn_window { args = claude_args(AI.MODELS.tl), cwd = cwd }
  local tr = tl:split {
    direction = 'Right',  size = 1 - AI.LEFT_RATIO,
    args = claude_args(AI.MODELS.tr), cwd = cwd,
  }
  tl:split { direction = 'Bottom', size = 1 - AI.LEFT_TOP_RATIO, cwd = cwd }
  tr:split {
    direction = 'Bottom', size = 1 - AI.RIGHT_TOP_RATIO,
    args = claude_args(AI.MODELS.br), cwd = cwd,
  }
  tl:activate()
end

-- Bound in §5:
-- { key = 'n', mods = 'CTRL|SUPER',
--   action = wezterm.action_callback(open_ai_mode) }
```

The ratios `0.65 / 0.82 / 0.50` carry over verbatim from the reference `aimode.py` (`LEFT_RATIO`, `LEFT_TOP_RATIO`, `RIGHT_TOP_RATIO`) — the user already tuned them on macOS, no reason to re-tune.

### 3.3 AI Mode hotkey (per OS)

Modifier choice is OS-aware because `WIN+N` and `ALT+N` each have their own conflicts:

| OS | Modifier | Why |
| --- | --- | --- |
| Windows | `CTRL\|ALT\|n` | `WIN+N` is grabbed by the OS Notification Center before WezTerm sees it. **Verified on a real Windows 11 box.** |
| macOS | `CTRL\|SUPER\|n` (= `CTRL\|CMD\|n`) | `ALT+N` is the dead key for `~` on Spanish/US-International layouts. SUPER (Command) is the standard macOS app modifier. |
| Linux | `CTRL\|SUPER\|n` | SUPER is the Win key, free on standard DEs. Same binding as macOS keeps muscle memory consistent. |

The `wezterm.lua` resolves this in §5 with a one-liner:

```lua
local ai_mode_mods = wezterm.target_triple:find 'windows' and 'CTRL|ALT'
                  or 'CTRL|SUPER'
```

### 3.5 Shell profile picker (§5 of the file)

Windows-only block. Three pieces:

1. **Hardcoded color schemes.** Four schemes are defined inline as Lua tables and injected into `config.color_schemes`:

   | Scheme | Background | Foreground | Used for |
   | --- | --- | --- | --- |
   | `GitBash` | `#000000` | `#BFBFBF` | Git Bash |
   | `Campbell` | `#0C0C0C` | `#CCCCCC` | PowerShell 7, CMD |
   | `Campbell Powershell` | `#012456` | `#CCCCCC` | PowerShell 5 |
   | `Ubuntu` | `#300A24` | `#BFBFBF` | WSL |

2. **Hardcoded profile list.** Five entries in fixed order: Git Bash → PowerShell 7 → Ubuntu → CMD → PowerShell 5. Each entry has `label`, `args` (no shell wrapper, direct CreateProcess), `cwd` (`%USERPROFILE%` for shells that benefit from it), and `color_scheme`. `os.getenv('ProgramFiles')`, `SystemRoot`, `USERPROFILE` are resolved at config load. The picker displays them in declaration order with numeric shortcuts 1–5.

   The same `exe_to_scheme` mapping (`bash.exe → GitBash`, `pwsh.exe → Campbell`, `powershell.exe → Campbell Powershell`, `cmd.exe → Campbell`, `wsl.exe → Ubuntu`) drives the **global default** — `config.color_scheme` is set to match `config.default_prog[1]` from §2, so the very first window (which spawns the default shell, not via the picker) opens with shell-appropriate colors instead of the §3 fallback.

3. **Picker.** `show_profile_picker(window, pane)` builds the InputSelector choices in declared order (insertion order, no sort), with fuzzy search enabled. The selection callback calls `mux.spawn_window{args=…, cwd=…}` then `mux_window:gui_window():set_config_overrides{ color_scheme = … }` for the per-window scheme. If the GUI window isn't materialized yet, the override is stashed in `pending_scheme_by_window` and applied by the `window-focus-changed` handler the next time the new window receives focus.

The picker is invoked by:

- The `new-tab-button-click` event handler (left-click on "+"), which returns `false` to suppress WezTerm's default new-tab.
- A `CTRL+SHIFT+T` keyboard shortcut registered in §6 (Windows only).

**Trade-off**: each profile pick opens a NEW WINDOW, not a tab. WezTerm's `set_config_overrides` is window-scoped, so per-tab color schemes aren't possible. If color-scheme-per-profile isn't important, swap `mux.spawn_window` for `current_window:mux_window():spawn_tab` to get tabs in the current window sharing one scheme. See `tmp/wezterm-research/06-wt-import.md` for the design history (we briefly imported from WT's settings.json before switching to the hardcoded list).

### 3.4 Mouse bindings (§7 of the file)

Mirrors Windows Terminal's behavior so muscle memory carries over:

- Right-click with text selected → copies to clipboard + clears the selection.
- Right-click with nothing selected → pastes from clipboard.

Implementation uses `wezterm.action_callback` so the same binding does both depending on `window:get_selection_text_for_pane(pane)`. WezTerm's default left-drag-to-select and `CTRL+SHIFT+C/V` keyboard shortcuts remain available.

The complete file (with section headers and full comments) is at `~/.config/wezterm/wezterm.lua` and is the source of truth — this doc shows the structure, not a verbatim copy.

## 4. Cross-platform behavior matrix

| OS | Shell | OSC 7 source | CWD detection | Config path | claude location |
| --- | --- | --- | --- | --- | --- |
| macOS | zsh | vendored `wezterm.sh` sourced from `.zshrc` | `Url.file_path` (POSIX) | `~/.config/wezterm/wezterm.lua` | usually `/opt/homebrew/bin/claude` |
| Linux | zsh / bash | vendored `wezterm.sh` sourced from rc | `Url.file_path` (POSIX) | `~/.config/wezterm/wezterm.lua` | usually `~/.local/bin/claude` |
| Windows | Git Bash | vendored `wezterm.sh` sourced from `.bashrc` | `Url.file_path` returns `/c/Users/…`, accepted by chdir as-is | `%USERPROFILE%\.wezterm.lua` or `%USERPROFILE%\.config\wezterm\wezterm.lua` | `claude.exe` on PATH |
| Windows | PowerShell 7 | custom `Global:Prompt` in `$PROFILE` | `Url.file_path` returns `/C:/Users/…`, regex strips leading slash | same as Git Bash | same |
| Windows | cmd.exe | none (or `set_environment_variables.prompt`) | falls through to `get_foreground_process_info().cwd` | same as Git Bash | same |

## 5. Shell integration requirements

The `pane_cwd()` fallback chain means AI Mode "works" without OSC 7, but accuracy improves with it. Snippets, by shell:

**zsh / bash (incl. Git Bash on Windows)** — copy the WezTerm asset and source it:

```sh
# One-time:
cp .../assets/shell-integration/wezterm.sh ~/.config/wezterm/wezterm.sh

# In ~/.zshrc or ~/.bashrc:
[[ -n "$WEZTERM_PANE" ]] && [[ -f "$HOME/.config/wezterm/wezterm.sh" ]] \
  && source "$HOME/.config/wezterm/wezterm.sh"
```

**PowerShell 7** — append to `$PROFILE`:

```powershell
function Global:Prompt {
  $p = $ExecutionContext.SessionState.Path.CurrentLocation
  if ($p.Provider.Name -eq 'FileSystem' -and $env:WEZTERM_PANE) {
    $esc  = [char]27
    $path = $p.ProviderPath -replace '\\','/'
    Write-Host -NoNewline "$esc]7;file://$env:COMPUTERNAME/$path$esc\"
  }
  "PS $p$('>' * ($nestedPromptLevel + 1)) "
}
```

(If using Starship, hook `Invoke-Starship-PreCommand` instead — see `tmp/wezterm-research/04-shell-integration.md`.)

**cmd.exe** — not a primary target. Either skip (rely on process-info fallback) or set the prompt env var via `config.set_environment_variables.prompt`.

The `WEZTERM_PANE` guard is set by WezTerm in every spawned process — clean signal that OSC 7 is welcome.

## 6. Trade-offs and known issues

- **Direct-spawn means panes close when claude exits.** The simplest fix is to wrap each claude invocation in a shell that drops back to a prompt: `args = { '/bin/zsh', '-c', 'claude --model opus; exec zsh' }`. Not done by default — most claude exits are intentional, and rapid-relaunch is two keystrokes (`CTRL+SHIFT+W`, `CTRL+SUPER+N`).
- **WIN+N collision on Windows.** The OS opens the Notification Center on `WIN+N`. WezTerm captures the keystroke first in practice, but if it doesn't, switch to `CTRL|SHIFT|ALT+n` or define a leader chord.
- **OSC 7 missing on cmd.exe.** Falls through to `get_foreground_process_info().cwd`, which is heuristic on Windows but works in the common case.
- **Git Bash emits `/c/Users/…` paths.** The Windows leading-slash strip in `pane_cwd()` doesn't transform these (regex requires `:`), but Windows accepts forward-slash paths for `chdir`, so it doesn't matter.
- **`claude` not on PATH.** Each claude pane closes immediately on spawn; the shell pane stays open. There's no graceful "claude not found" message. Acceptable trade-off — installing claude is a setup step, not an AI Mode concern.
- **Hot reload caveat.** `mux.spawn_window` callbacks reload cleanly, but if you change `config.default_prog` you need to spawn a new pane to see it (existing panes keep their old shell).

## 7. Future devcli installer plan

Checklist for the phase that ships WezTerm via devcli. **Not done yet.**

### Tools.json entry

Add to `install/tools.json` under tag `core` (or a new `terminal` tag — discuss before creating). Per-platform install methods:

```json
{
  "name": "wezterm",
  "tags": ["core"],
  "platforms": {
    "macos":   { "method": "brew",   "package": "wezterm",   "cask": true },
    "windows": { "method": "winget", "package": "wez.wezterm" },
    "debian":  { "method": "deb-url", "url": "https://github.com/wez/wezterm/releases/latest/download/wezterm.deb" },
    "fedora":  { "method": "dnf",     "package": "wezterm" },
    "arch":    { "method": "pacman",  "package": "wezterm" }
  }
}
```

Method names should match what `install/02-packages.{sh,ps1}` already understands. Alternative for Debian: AppImage (set `WEZTERM_APPIMAGE_PATH`).

### Dotfile mapping

- Add `dotfiles/.config/wezterm/wezterm.lua` — copy of the super-config from `~/.config/wezterm/wezterm.lua`. Because the file embeds the shell-detection cascade itself (§2), no per-OS dotfile variants are needed — one source.
- Add `dotfiles/wezterm.sh` — vendored copy of `tmp/wezterm/assets/shell-integration/wezterm.sh`.
- Extend `install/03-dotfiles.json` with both mappings:
  - `wezterm.lua` → `~/.config/wezterm/wezterm.lua` on all platforms (Windows: `%USERPROFILE%\.config\wezterm\wezterm.lua`).
  - `wezterm.sh` → `~/.config/wezterm/wezterm.sh` on all platforms.
  - **Platform filter**: skip on headless WSL (no GUI, WezTerm is a desktop app).

### Shell integration line

Append the OSC 7 source-line to `dotfiles/.zshrc`, `dotfiles/win.gitbash.bashrc`, and `dotfiles/Microsoft.PowerShell_profile.ps1`, guarded by `WEZTERM_PANE`-presence so non-WezTerm shells are unaffected.

```sh
# in dotfiles/.zshrc and dotfiles/win.gitbash.bashrc
[[ -n "$WEZTERM_PANE" ]] && [[ -f "$HOME/.config/wezterm/wezterm.sh" ]] \
  && source "$HOME/.config/wezterm/wezterm.sh"
```

```powershell
# in dotfiles/Microsoft.PowerShell_profile.ps1 — wrap the existing Prompt
# function (or add one if absent) with the OSC 7 emission shown in §5.
```

### tmux.conf check

`dotfiles/.tmux.conf` already exists. Confirm `CTRL+SUPER+N` doesn't collide with any tmux binding (it shouldn't — tmux uses prefix-style bindings, not raw modifiers). No change expected.

### Profiles

`tools.json` profiles: WezTerm belongs in `dev` and `full`, **not** `minimal`. It's a desktop application; users on minimal/server profiles won't have a display server.

### Patterns to reuse

- `install/utils.sh::command_exists` — skip install when wezterm is already present.
- `install/03-dotfiles.json` schema — same shape for the new mappings.
- `dotfiles/.zshrc` already uses the conditional-guard idiom for shell integrations (e.g., the existing `mise activate` guard).
- `install/05-localtools.json` is **not** the right place — wezterm is a system tool, not a local helper script.

## 8. References

- Companion notes (gitignored): `tmp/wezterm-research/{00-index.md, 01-doc-bookmarks.md, 02-api-reference.md, 03-cwd-cross-platform.md, 04-shell-integration.md, 05-design-notes.md}`.
- Cloned WezTerm sources (gitignored): `tmp/wezterm/` (commit `577474d89ee61aef4a48145cdec82a638d874751`).
- Upstream: <https://wezfurlong.org/wezterm/>.
- iTerm prior art: ["iTerm in AI Mode"](https://luispa.com/posts/2026-04-25-iterm-modo-ia/) and `aimode.py`.

## 9. Migration trigger

When AI Mode is in production use on at least one Linux box and one Windows box without manual surgery, this doc moves from "research artifact" to "spec for an installer phase." At that point:

1. Cut a feature branch named `feature/wezterm-phase`.
2. Implement the §7 checklist.
3. Promote the relevant content from `tmp/wezterm-research/` notes (which are gitignored) into commit-able documentation under `docs/` or `install/README-wezterm.md`.
4. Delete this §9 — it's a self-contained marker.
