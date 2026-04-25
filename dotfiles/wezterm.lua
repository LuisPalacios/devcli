-- ════════════════════════════════════════════════════════════════════════════
-- wezterm.lua — Luis's super-terminal config
--
-- One config file, three OSes (macOS, Linux, Windows). Designed to be the
-- long-term home for terminal preferences and feature hotkeys, not just one
-- workflow. Sections are clearly delimited so adding a new feature later
-- (e.g. "Quake mode", workspace switcher, SSH multiplexer hotkey) is a copy
-- of an existing feature section, not a rewrite.
--
-- Layout of this file:
--   §1  Bootstrap & helpers      — io tricks shared by every section below
--   §2  Platform & shell choice  — cascade fallbacks per OS
--   §3  Appearance & defaults    — fonts, colors, dimensions, scrollback
--   §4  Feature: AI Mode         — 4-pane Claude workspace on a hotkey
--   §5  Feature: Shell picker    — (Windows only) hardcoded profile menu
--   §6  Key bindings             — registry of feature hotkeys (OS-aware mods)
--   §7  Mouse bindings           — Windows-Terminal-style right-click copy/paste
--
-- Companion docs (in this user's devcli repo):
--   • docs/wezterm-ai-mode.md       — internal context for the WezTerm setup
--   • tmp/wezterm-research/         — gitignored research notes
-- ════════════════════════════════════════════════════════════════════════════

-- ─── §1  Bootstrap & helpers ───────────────────────────────────────────────

local wezterm = require 'wezterm'
local mux     = wezterm.mux
local act     = wezterm.action
local config  = wezterm.config_builder()

-- Returns true if a regular file exists at `path`. Useful on Windows for
-- probing absolute exe locations (Program Files, System32, ...).
local function file_exists(path)
  local f = io.open(path, 'r')
  if f then f:close() return true end
  return false
end

-- Returns true if `cmd` resolves on the current PATH. Implemented via
-- `command -v`, so only call this on Unix branches — on Windows io.popen
-- falls back to cmd.exe which doesn't ship `command -v`.
local function unix_command_exists(cmd)
  local f = io.popen('command -v ' .. cmd .. ' 2>/dev/null')
  if not f then return false end
  local out = f:read('*a')
  f:close()
  return out and out:match('%S') ~= nil
end

-- Lower-cased basename of a path, e.g. "C:\Program Files\Git\bin\bash.exe"
-- → "bash.exe". Used to match the active shell against scheme defaults.
local function exe_basename(path)
  if not path or path == '' then return '' end
  return (path:match('([^\\/]+)$') or path):lower()
end

-- Forward declaration for the shell picker — defined inside §5
-- (Windows-only). §6 uses it conditionally.
local show_profile_picker


-- ─── §2  Platform & shell choice ───────────────────────────────────────────
--
-- target_triple is substring-matched so x86_64 / aarch64 variants both hit.
-- Each branch picks the best available shell with a cascade of fallbacks:
--
--   Windows :  Git Bash  →  PowerShell 7 (pwsh)  →  Windows PowerShell
--   Unix    :  zsh       →  bash                 →  sh
--
-- The cascade keeps the config portable across machines that may not have
-- the preferred shell installed (e.g. a fresh server with only sh).

if wezterm.target_triple:find 'windows' then
  local prog_files = os.getenv('ProgramFiles') or 'C:\\Program Files'
  local sys_root   = os.getenv('SystemRoot')   or 'C:\\Windows'

  local git_bash = prog_files .. '\\Git\\bin\\bash.exe'
  local pwsh_7   = prog_files .. '\\PowerShell\\7\\pwsh.exe'
  local win_ps   = sys_root   .. '\\System32\\WindowsPowerShell\\v1.0\\powershell.exe'

  if file_exists(git_bash) then
    config.default_prog = { git_bash, '-l', '-i' }
  elseif file_exists(pwsh_7) then
    config.default_prog = { pwsh_7, '-NoLogo' }
  else
    config.default_prog = { win_ps, '-NoLogo' }
  end

elseif wezterm.target_triple:find 'darwin' or wezterm.target_triple:find 'linux' then
  if unix_command_exists('zsh') then
    config.default_prog = { 'zsh', '-l' }
  elseif unix_command_exists('bash') then
    config.default_prog = { 'bash', '-l' }
  else
    config.default_prog = { 'sh', '-l' }
  end
end


-- ─── §3  Appearance & defaults ─────────────────────────────────────────────

config.initial_cols     = 200
config.initial_rows     = 50
config.font_size        = 11
config.scrollback_lines = 10000
config.audible_bell     = 'Disabled'

-- Global color scheme. Windows overrides this in §5 to match the default
-- shell (Git Bash → 'GitBash', pwsh → 'Campbell', …) so the very first
-- window opens with shell-appropriate colors.
--
-- ┌──────────────────────────────────────────────────────────────────────┐
-- │  TODO: try a different theme some day                                │
-- ├──────────────────────────────────────────────────────────────────────┤
-- │  WezTerm ships ~960 schemes from iTerm2-Color-Schemes, Gogh, base16. │
-- │  Browse with live previews:                                          │
-- │    https://wezfurlong.org/wezterm/colorschemes/index.html            │
-- │                                                                      │
-- │  Short list to evaluate (any of these can replace 'AdventureTime'):  │
-- │    Catppuccin Mocha / Catppuccin Latte / Catppuccin Frappé / Macchiato
-- │    Tokyo Night / Tokyo Night Storm / tokyonight_night (Gogh)         │
-- │    Gruvbox Dark / Gruvbox Light / GruvboxDark (Gogh)                 │
-- │    Solarized (dark/light) (terminal.sexy) / Builtin Solarized Dark   │
-- │    Dracula / Dracula+ / Dracula (Gogh)                               │
-- │    nord (Gogh) / Nord Light                                          │
-- │    OneDark / One Dark (Gogh) / OneHalfDark                           │
-- │    Monokai (terminal.sexy) / Monokai Pro / Monokai Pro (Gogh)        │
-- │    Github / GitHub Dark / Github (Gogh)                              │
-- │    Campbell / Campbell Powershell / Vintage   (Microsoft Console)    │
-- │                                                                      │
-- │  Preview live without saving the config — debug overlay (CTRL+SHIFT+L│
-- │  on Windows/Linux, SUPER+L on macOS), then paste:                    │
-- │    local w = wezterm.gui.gui_windows()[1]                            │
-- │    local o = w:get_config_overrides() or {}                          │
-- │    o.color_scheme = 'Tokyo Night'                                    │
-- │    w:set_config_overrides(o)                                         │
-- │  Revert by setting o.color_scheme = nil and reapplying.              │
-- │                                                                      │
-- │  Enumerate all bundled names:                                        │
-- │    for n,_ in pairs(wezterm.color.get_builtin_schemes()) do print(n) │
-- │    end                                                               │
-- └──────────────────────────────────────────────────────────────────────┘
config.color_scheme = 'AdventureTime'

-- Don't prompt "Really kill this window?" when closing — assume yes.
-- (Set to 'AlwaysPrompt' to restore the default if you ever lose work.)
config.window_close_confirmation = 'NeverPrompt'


-- ─── §4  Feature: AI Mode ──────────────────────────────────────────────────
--
-- One hotkey opens a new window with 4 panes anchored to the originating CWD:
--   ┌──────────────────────────┬──────────────┐
--   │                          │  sonnet      │
--   │       opus               ├──────────────┤
--   ├──────────────────────────┤  haiku       │
--   │  shell                   │              │
--   └──────────────────────────┴──────────────┘
-- Each Claude pane runs `claude --model <X>` directly as its foreground
-- process — no shell underneath, no send_text race. The bottom-left pane is
-- the platform default shell from §2.
--
-- Reference: ports the iTerm2 Python script from
--   ~/Library/Application Support/iTerm2/Scripts/AutoLaunch/aimode.py
-- The three ratios below carry over verbatim from that script.

local AI = {
  LEFT_RATIO       = 0.65,                                    -- opus column
  LEFT_TOP_RATIO   = 0.82,                                    -- opus share of left column
  RIGHT_TOP_RATIO  = 0.50,                                    -- sonnet vs haiku
  MODELS           = { tl = 'opus', tr = 'sonnet', br = 'haiku' },
  CLAUDE_BIN       = 'claude',
}

-- Resolves the CWD of `pane` across OSes / shells.
-- Order: OSC 7 (Url.file_path) → foreground process info → home dir.
local function pane_cwd(pane)
  local url = pane:get_current_working_dir()
  if url and url.file_path then
    local p = url.file_path
    -- Windows: Url.file_path returns "/C:/Users/..." — strip the leading
    -- slash so native exes get a clean path. Git Bash emits "/c/Users/..."
    -- which doesn't match the regex (no colon) and is accepted as-is by chdir.
    if wezterm.target_triple:find 'windows' then
      p = p:gsub('^/([A-Za-z]:)', '%1')
    end
    return p
  end
  local info = pane:get_foreground_process_info()
  if info and info.cwd and info.cwd ~= '' then
    return info.cwd
  end
  return wezterm.home_dir
end

-- Builds the 4-pane layout in a NEW window, anchored to the source pane's CWD.
-- Split order (matches the iTerm aimode.py rationale):
--   1. spawn_window      → new window, top-left = opus
--   2. tl:split Right    → creates the right column (sonnet on top)
--   3. tl:split Bottom   → splits the LEFT column → shell strip below opus
--   4. tr:split Bottom   → splits the RIGHT column → haiku below sonnet
-- Steps 3 and 4 split different parents, so the left and right columns
-- end up with independent horizontal dividers (sized by LEFT_TOP_RATIO and
-- RIGHT_TOP_RATIO respectively).
local function open_ai_mode(_window, source_pane)
  local cwd = pane_cwd(source_pane)
  local claude_args = function(model)
    return { AI.CLAUDE_BIN, '--model', model }
  end

  -- 1. New window with opus as the initial pane.
  local _tab, tl = mux.spawn_window {
    args = claude_args(AI.MODELS.tl),
    cwd  = cwd,
  }

  -- 2. Right column (sonnet); size = right column share = 1 - LEFT_RATIO.
  local tr = tl:split {
    direction = 'Right',
    size      = 1 - AI.LEFT_RATIO,
    args      = claude_args(AI.MODELS.tr),
    cwd       = cwd,
  }

  -- 3. Shell strip below opus; size = bottom share of LEFT column.
  tl:split {
    direction = 'Bottom',
    size      = 1 - AI.LEFT_TOP_RATIO,
    cwd       = cwd,
    -- no args ⇒ uses config.default_prog from §2
  }

  -- 4. Haiku below sonnet; size = bottom share of RIGHT column.
  tr:split {
    direction = 'Bottom',
    size      = 1 - AI.RIGHT_TOP_RATIO,
    args      = claude_args(AI.MODELS.br),
    cwd       = cwd,
  }

  tl:activate()
end


-- ─── §5  Feature: Shell profile picker (Windows-only) ──────────────────────
--
-- Click "+" or press CTRL+SHIFT+T to open a fuzzy picker; the chosen
-- profile spawns a NEW WINDOW with its own color scheme applied.
--
-- Why hardcoded? Earlier drafts read Windows Terminal's settings.json on
-- every boot to mirror the user's WT profiles. That worked but tied this
-- config to whatever state WT happened to be in (non-idempotent: WT edits
-- changed WezTerm behavior silently). Now this file is the single source
-- of truth; the same config produces the same behavior on every box and
-- ships unchanged through the devcli installer.
--
-- "New window per profile" is required because WezTerm scopes color
-- scheme overrides to the GUI window, not the tab. To get tabs sharing a
-- single scheme instead, replace mux.spawn_window with the active
-- window's mux_window:spawn_tab in the picker callback below.
--
-- To add / change profiles: edit `schemes` and `profiles` below. The
-- order of `profiles` is the order the picker displays them.

if wezterm.target_triple:find 'windows' then
  -- Hardcoded color schemes (canonical Microsoft Console + Ubuntu palettes).
  -- Available globally via config.color_scheme and per-window via
  -- mux_window:gui_window():set_config_overrides{ color_scheme = '…' }.
  local schemes = {
    -- Git Bash — fg #BFBFBF on black; the palette the user maintained
    -- in WT's settings.json (kept verbatim).
    ['GitBash'] = {
      foreground    = '#BFBFBF', background = '#000000',
      cursor_bg     = '#FFFFFF', cursor_fg  = '#000000',
      cursor_border = '#FFFFFF',
      selection_bg  = '#FFFFFF', selection_fg = '#000000',
      ansi    = { '#0C0C0C', '#BF0000', '#00A400', '#BFBF00',
                  '#6060FF', '#BF00BF', '#3A96DD', '#FFFFFF' },
      brights = { '#767676', '#E74856', '#16C60C', '#F9F1A5',
                  '#3B78FF', '#B4009E', '#61D6D6', '#F2F2F2' },
    },
    -- Microsoft Console default — used by PowerShell 7 and cmd.exe.
    ['Campbell'] = {
      foreground    = '#CCCCCC', background = '#0C0C0C',
      cursor_bg     = '#FFFFFF', cursor_fg  = '#0C0C0C',
      cursor_border = '#FFFFFF',
      selection_bg  = '#FFFFFF', selection_fg = '#000000',
      ansi    = { '#0C0C0C', '#C50F1F', '#13A10E', '#C19C00',
                  '#0037DA', '#881798', '#3A96DD', '#CCCCCC' },
      brights = { '#767676', '#E74856', '#16C60C', '#F9F1A5',
                  '#3B78FF', '#B4009E', '#61D6D6', '#F2F2F2' },
    },
    -- Microsoft Console (PowerShell 5) — same palette as Campbell with
    -- the iconic blue background.
    ['Campbell Powershell'] = {
      foreground    = '#CCCCCC', background = '#012456',
      cursor_bg     = '#FFFFFF', cursor_fg  = '#012456',
      cursor_border = '#FFFFFF',
      selection_bg  = '#FFFFFF', selection_fg = '#000000',
      ansi    = { '#0C0C0C', '#C50F1F', '#13A10E', '#C19C00',
                  '#0037DA', '#881798', '#3A96DD', '#CCCCCC' },
      brights = { '#767676', '#E74856', '#16C60C', '#F9F1A5',
                  '#3B78FF', '#B4009E', '#61D6D6', '#F2F2F2' },
    },
    -- Standard Ubuntu Terminal palette (Tango-derived) — used by WSL.
    ['Ubuntu'] = {
      foreground    = '#BFBFBF', background = '#300A24',
      cursor_bg     = '#BFBFBF', cursor_fg  = '#300A24',
      cursor_border = '#BFBFBF',
      selection_bg  = '#B5D5FF', selection_fg = '#000000',
      ansi    = { '#2E3436', '#CC0000', '#4E9A06', '#C4A000',
                  '#3465A4', '#75507B', '#06989A', '#D3D7CF' },
      brights = { '#555753', '#EF2929', '#8AE234', '#FCE94F',
                  '#729FCF', '#AD7FA8', '#34E2E2', '#EEEEEC' },
    },
  }

  -- Inject schemes into config.color_schemes so set_config_overrides
  -- can reference them by name.
  config.color_schemes = config.color_schemes or {}
  for name, scheme in pairs(schemes) do
    config.color_schemes[name] = scheme
  end

  -- Hardcoded profile list. Order matters — the picker displays them top
  -- to bottom in this exact order, with numeric shortcuts 1-5.
  local prog_files = os.getenv('ProgramFiles') or 'C:\\Program Files'
  local sys_root   = os.getenv('SystemRoot')   or 'C:\\Windows'
  local home       = os.getenv('USERPROFILE')

  local profiles = {
    {
      label        = 'Git Bash',
      args         = { prog_files .. '\\Git\\bin\\bash.exe', '--login', '-i', '-l' },
      cwd          = home,
      color_scheme = 'GitBash',
    },
    {
      label        = 'PowerShell 7',
      args         = { 'pwsh.exe' },
      cwd          = nil,
      color_scheme = 'Campbell',
    },
    {
      label        = 'Ubuntu',
      args         = { 'wsl.exe', '-d', 'Ubuntu-24.04' },
      cwd          = nil,
      color_scheme = 'Ubuntu',
    },
    {
      label        = 'CMD',
      args         = {
        sys_root .. '\\System32\\cmd.exe',
        '/k',
        (home or '') .. '\\cmd_aliases.cmd',
      },
      cwd          = home,
      color_scheme = 'Campbell',
    },
    {
      label        = 'PowerShell 5',
      args         = {
        sys_root .. '\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
      },
      cwd          = nil,
      color_scheme = 'Campbell Powershell',
    },
  }

  -- Set the global default scheme to match §2's chosen shell, so the very
  -- first window (which spawns config.default_prog, not via the picker)
  -- opens with shell-appropriate colors instead of §3's AdventureTime.
  do
    local default_exe = exe_basename(config.default_prog and config.default_prog[1])
    local exe_to_scheme = {
      ['bash.exe']       = 'GitBash',
      ['pwsh.exe']       = 'Campbell',
      ['powershell.exe'] = 'Campbell Powershell',
      ['cmd.exe']        = 'Campbell',
      ['wsl.exe']        = 'Ubuntu',
    }
    local default_scheme = exe_to_scheme[default_exe]
    if default_scheme and config.color_schemes[default_scheme] then
      config.color_scheme = default_scheme
    end
  end

  -- Deferred color-scheme overrides.
  --
  -- mux.spawn_window returns the new MuxWindow synchronously, but the GUI
  -- window may not be realized yet — mux_window:gui_window() returns nil.
  -- When that happens we stash the desired scheme here, keyed by window id;
  -- the window-focus-changed handler below applies it the first time the
  -- new window receives focus (which is right after spawn).
  local pending_scheme_by_window = {}

  wezterm.on('window-focus-changed', function(win, _pn)
    local key = tostring(win:window_id())
    local pending = pending_scheme_by_window[key]
    if pending then
      local overrides = win:get_config_overrides() or {}
      if overrides.color_scheme ~= pending then
        overrides.color_scheme = pending
        win:set_config_overrides(overrides)
      end
      pending_scheme_by_window[key] = nil
    end
  end)

  -- The picker: build choices in declared order, show InputSelector, on
  -- selection spawn a new window and apply the per-window color scheme.
  show_profile_picker = function(window, pane)
    local choices = {}
    for i, p in ipairs(profiles) do
      table.insert(choices, { id = tostring(i), label = p.label })
    end

    window:perform_action(act.InputSelector {
      title       = 'Open a shell',
      description = 'Pick a profile — opens in a new window with its color scheme.',
      fuzzy       = true,
      choices     = choices,
      action = wezterm.action_callback(function(_win, _pn, id, _label)
        if not id then return end             -- cancelled (Esc)
        local idx = tonumber(id)
        local prof = idx and profiles[idx]
        if not prof then return end

        local _tab, _new_pane, new_mux = mux.spawn_window {
          args = prof.args,
          cwd  = prof.cwd,
        }

        -- Apply the per-window color scheme override. Try sync first; if the
        -- GUI window isn't realized yet, defer to the window-focus-changed
        -- handler above (which applies the moment the window gets focus).
        if prof.color_scheme and new_mux then
          local key = tostring(new_mux:window_id())
          local gui = new_mux:gui_window()
          if gui then
            local overrides = gui:get_config_overrides() or {}
            overrides.color_scheme = prof.color_scheme
            gui:set_config_overrides(overrides)
          else
            pending_scheme_by_window[key] = prof.color_scheme
          end
        end
      end),
    }, pane)
  end

  -- "+" tab button → show the picker instead of the default "new tab".
  wezterm.on('new-tab-button-click', function(window, pane, button, _default)
    if button == 'Left' and show_profile_picker then
      show_profile_picker(window, pane)
      return false   -- suppress default new-tab behavior
    end
  end)
end


-- ─── §6  Key bindings ──────────────────────────────────────────────────────
--
-- Modifier conventions per OS (the super-config picks the right one):
--   Windows : CTRL|ALT  — WIN+N is taken by Notification Center.
--   macOS   : CTRL|SUPER (= CTRL|CMD) — ALT+N produces dead-key `~`.
--   Linux   : CTRL|SUPER — Super is the Win key, free on standard DEs.
-- Hotkeys fire from any pane. Add new feature hotkeys to this table.

local ai_mode_mods = wezterm.target_triple:find 'windows' and 'CTRL|ALT'
                  or 'CTRL|SUPER'

local key_bindings = {
  -- AI Mode (§4): four-pane Claude workspace anchored to current CWD.
  {
    key    = 'n',
    mods   = ai_mode_mods,
    action = wezterm.action_callback(open_ai_mode),
  },
}

-- Shell picker (§5): keyboard alternative to clicking "+".
if show_profile_picker then
  table.insert(key_bindings, {
    key    = 't',
    mods   = 'CTRL|SHIFT',
    action = wezterm.action_callback(show_profile_picker),
  })
end

config.keys = key_bindings


-- ─── §7  Mouse bindings ────────────────────────────────────────────────────
--
-- Windows-Terminal-style right-click:
--   • If text is selected, right-click copies it (and clears the selection).
--   • If nothing is selected, right-click pastes from the clipboard.
-- This overrides WezTerm's default right-click (which is "extend selection").

config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods  = 'NONE',
    action = wezterm.action_callback(function(window, pane)
      local sel = window:get_selection_text_for_pane(pane)
      if sel and sel ~= '' then
        window:perform_action(
          wezterm.action.CopyTo 'ClipboardAndPrimarySelection', pane)
        window:perform_action(wezterm.action.ClearSelection, pane)
      else
        window:perform_action(wezterm.action.PasteFrom 'Clipboard', pane)
      end
    end),
  },
}


return config
