-- ════════════════════════════════════════════════════════════════════════════
-- wezterm.lua — super-config de terminal de Luis
--
-- Una sola config, tres SO (macOS, Linux, Windows). Pensado como hogar a
-- largo plazo de las preferencias del terminal y atajos a distintas funcionalidades, no
-- como un único workflow. Las secciones están claramente delimitadas para
-- que añadir una funcionalidad nueva (p.ej. "Quake mode", workspace switcher,
-- atajo SSH multiplexer) sea copiar una sección existente, no rehacer
-- el fichero.
--
-- Estructura del fichero:
--   §0  Personalización             — knobs ajustables por el usuario (edítame primero)
--   §1  Bootstrap & helpers         — trucos de I/O compartidos por el resto de secciones
--   §2  Plataforma y shell          — cascada de fallbacks por SO
--   §3  Apariencia y defaults       — fuentes, colores, dimensiones, scrollback
--   §4  Funcionalidad: Modo IA      — workspace de 4 panes con Claude en un atajo
--   §5  Funcionalidad: Shell picker — (sólo Windows) menú de perfiles hardcoded
--   §6  Funcionalidad: Window state — recuerda tamaño + maximizado; centra la primera ventana
--   §7  Key bindings                — registro de atajos a distintas funcionalidades (mods OS-aware)
--   §8  Mouse bindings              — copy/paste con click derecho estilo Windows Terminal
--
-- Docs asociados (en el repo devcli del autor):
--   • https://github.com/LuisPalacios/devcli  — home del proyecto
--   • .claude/context/wezterm-ai-mode.md — contexto interno (lo carga Claude)
--   • tmp/wezterm-research/               — notas de investigación gitignored
--   • https://wezterm.org/                — home del proyecto wezterm
--   • https://wezterm.org/colorschemes    — color schemes de wezterm
--   • https://github.com/wezterm/wezterm  — repo de wezterm en GitHub
-- ════════════════════════════════════════════════════════════════════════════

-- ─── §0  Personalización ───────────────────────────────────────────────────
--
-- Knobs que querrás adaptar a tu gusto. Edita este bloque y reinicia
-- WezTerm (o pulsa CTRL+SHIFT+R) para que los cambios surtan efecto.

local CUSTOMIZE = {
  -- Argumentos extra que se inyectan en CADA pane que lance `claude` en
  -- Modo IA (§4). Tabla de strings; se insertan ANTES de `--model X`,
  -- así que componen sin colisionar con la elección de modelo.
  --
  -- Default: arranca con `--allow-dangerously-skip-permissions` para
  -- saltarse el prompt de permisos al lanzar `claude`. Si prefieres
  -- que `claude` te pida confirmación cada vez, déjalo vacío:
  --   CLAUDE_EXTRA_ARGS = {},
  CLAUDE_EXTRA_ARGS = { '--allow-dangerously-skip-permissions' },
}

-- ─── §1  Bootstrap & helpers ───────────────────────────────────────────────

local wezterm = require 'wezterm'
local mux     = wezterm.mux
local act     = wezterm.action
local config  = wezterm.config_builder()

-- Devuelve true si existe un archivo regular en `path`. Útil en Windows
-- para sondear rutas absolutas de ejecutables (Program Files, System32...).
local function file_exists(path)
  local f = io.open(path, 'r')
  if f then f:close() return true end
  return false
end

-- Devuelve true si `cmd` resuelve en el PATH actual. Implementado vía
-- `command -v`, así que sólo conviene llamarlo en ramas Unix — en Windows
-- io.popen cae a cmd.exe, que no trae `command -v`.
local function unix_command_exists(cmd)
  local f = io.popen('command -v ' .. cmd .. ' 2>/dev/null')
  if not f then return false end
  local out = f:read('*a')
  f:close()
  return out and out:match('%S') ~= nil
end

-- Basename en minúsculas de una ruta, p.ej. "C:\Program Files\Git\bin\bash.exe"
-- → "bash.exe". Se usa para emparejar el shell activo con los defaults de
-- color scheme.
local function exe_basename(path)
  if not path or path == '' then return '' end
  return (path:match('([^\\/]+)$') or path):lower()
end

-- Forward-declarations del shell picker (§5, sólo Windows). §7 (key
-- bindings) los referencia condicionalmente.
local show_profile_picker
local spawn_tab_same_shell

-- Forward-declaration del helper de tamaño de §6, usado por §4 (Modo IA)
-- y §5 (shell picker) para que cada ventana recién creada herede el
-- tamaño guardado.
local apply_saved_size_to


-- ─── §2  Plataforma y shell ────────────────────────────────────────────────
--
-- target_triple se compara por substring, así que tanto las variantes
-- x86_64 como aarch64 hacen match. Cada rama escoge el mejor shell
-- disponible con una cascada de fallbacks:
--
--   Windows :  Git Bash  →  PowerShell 7 (pwsh)  →  Windows PowerShell
--   Unix    :  zsh       →  bash                 →  sh
--
-- La cascada mantiene la config portable entre máquinas que pueden no
-- tener instalado el shell preferido (p.ej. un servidor recién provisionado
-- con sólo sh).

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


-- ─── §3  Apariencia y defaults ─────────────────────────────────────────────

config.initial_cols     = 200
config.initial_rows     = 50
-- Tamaño de fuente por SO. macOS retina renderiza más pequeño con el mismo
-- pt size, así que sube un par de puntos para emparejar el tamaño visual;
-- Linux queda en medio. En Windows 13 pt equivale a pulsar Ctrl-+ dos veces
-- sobre 11 pt (cada pulsación = +10%, ver wezterm.action.IncreaseFontSize).
config.font_size        = (wezterm.target_triple:find 'darwin' and 13)
                       or (wezterm.target_triple:find 'linux'  and 12)
                       or 13
-- Efectivamente ilimitado para uso normal. WezTerm no tiene una opción
-- "infinito" real; esto guarda 100 K líneas/pane en RAM (~10 MB a 100 B/línea
-- de media). Súbelo si haces scroll por encima de eso; 1_000_000 es seguro.
config.scrollback_lines = 100000
config.audible_bell     = 'Disabled'

-- Scrollbar visible en el borde derecho del pane. Útil con
-- `scrollback_lines = 100000`: el thumb escala con la posición dentro
-- del buffer y se puede arrastrar para navegar grandes scrollbacks
-- mucho más rápido que scrolleando línea a línea con la rueda.
-- Color del thumb se hereda del color scheme activo (suele ser un
-- gris discreto integrado con el tema).
config.enable_scroll_bar = true

-- Color scheme global. Windows lo sobreescribe en §5 para emparejarlo con
-- el shell por defecto, así la primera ventana abre con los colores
-- propios del shell.
--
-- ┌──────────────────────────────────────────────────────────────────────┐
-- │  TODO: probar otro tema algún día                                    │
-- ├──────────────────────────────────────────────────────────────────────┤
-- │  WezTerm trae ~960 schemes de iTerm2-Color-Schemes, Gogh, base16.    │
-- │  Navega con previews en vivo:                                        │
-- │    https://wezfurlong.org/wezterm/colorschemes/index.html            │
-- │                                                                      │
-- │  Lista corta para evaluar (cualquiera puede sustituir al default):   │
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
-- │  Dos formas de previsualizar en vivo (sin editar, sólo esta vent.):  │
-- │  ① Pulsa CTRL+SHIFT+E — fuzzy picker sobre cada scheme bundled.      │
-- │     Escribe para filtrar, Enter aplica, Esc revierte. (Ver §3 abajo.)│
-- │  ② O, en el debug overlay (CTRL+SHIFT+L en Win/Linux, SUPER+L en     │
-- │     macOS), pega esto COMO UN ÚNICO BLOQUE — el overlay trata cada   │
-- │     línea como su propio chunk, así que los locals no sobreviven     │
-- │     entre líneas:                                                    │
-- │       do                                                             │
-- │         local w = wezterm.gui.gui_windows()[1]                       │
-- │         local o = w:get_config_overrides() or {}                     │
-- │         o.color_scheme = 'Tokyo Night'                               │
-- │         w:set_config_overrides(o)                                    │
-- │       end                                                            │
-- │  Revierte poniendo o.color_scheme = nil y reaplicando. Para hacer    │
-- │  permanente la elección, edita config.color_scheme abajo.            │
-- │                                                                      │
-- │  Enumera todos los nombres bundled desde el debug overlay:           │
-- │    for n,_ in pairs(wezterm.color.get_builtin_schemes()) do print(n) │
-- │    end                                                               │
-- └──────────────────────────────────────────────────────────────────────┘
-- config.color_scheme = 'iTerm2 Dark Background'
config.color_scheme = 'LP-GitBash'

-- No preguntar "¿Realmente quieres matar esta ventana?" al cerrar —
-- asumir que sí. (Pon 'AlwaysPrompt' para restaurar el default si alguna
-- vez pierdes trabajo por accidente.)
config.window_close_confirmation = 'NeverPrompt'

-- Theme picker en vivo. Bindeado a CTRL+SHIFT+E en §7.
-- Abre un InputSelector fuzzy sobre todos los schemes disponibles — tanto
-- los LP-* del usuario (de la inyección a config.color_schemes en §5) como
-- los ~960 bundled de WezTerm. Al seleccionar aplica vía
-- set_config_overrides — sólo a esta ventana, no toca este fichero.
-- Esc cancela (sin cambios). Para hacer permanente un tema elegido,
-- edita config.color_scheme arriba con su nombre.
local function show_theme_picker(window, pane)
  local seen = {}
  local choices = {}
  local function add(name)
    if not seen[name] then
      seen[name] = true
      table.insert(choices, { id = name, label = name })
    end
  end
  -- Schemes del usuario primero. config.color_schemes lo puebla §5 al
  -- cargar la config, así que cuando este picker se dispara ya están
  -- disponibles.
  if config.color_schemes then
    for name, _ in pairs(config.color_schemes) do add(name) end
  end
  for name, _ in pairs(wezterm.color.get_builtin_schemes()) do add(name) end
  table.sort(choices, function(a, b)
    return a.label:lower() < b.label:lower()
  end)
  window:perform_action(act.InputSelector {
    title       = 'Preview a color scheme',
    description = 'Type to filter, Enter applies (this window only). Esc cancels.',
    fuzzy       = true,
    choices     = choices,
    action = wezterm.action_callback(function(win, _pn, id, _label)
      if not id then return end           -- cancelado (Esc)
      local overrides = win:get_config_overrides() or {}
      overrides.color_scheme = id
      win:set_config_overrides(overrides)
    end),
  }, pane)
end


-- ─── §4  Funcionalidad: Modo IA ────────────────────────────────────────────
--
-- Un atajo abre una ventana nueva con 4 panes anclados al CWD de origen:
--   ┌──────────────────────────┬──────────────┐
--   │                          │  sonnet      │
--   │       opus               ├──────────────┤
--   ├──────────────────────────┤  haiku       │
--   │  shell                   │              │
--   └──────────────────────────┴──────────────┘
-- Cada pane de Claude ejecuta `claude --model <X>` directamente como su
-- proceso foreground — sin shell intermedio, sin la carrera de send_text.
-- El pane abajo-izquierda es el shell por defecto de la plataforma (§2).
--
-- Referencia: porta el script Python de iTerm2
--   ~/Library/Application Support/iTerm2/Scripts/AutoLaunch/aimode.py
-- Las tres ratios de abajo se mantienen verbatim de ese script.

-- Resuelve el binario claude al cargar la config. Las apps GUI de macOS
-- lanzadas desde Finder/Spotlight heredan un PATH mínimo
-- (/usr/bin:/bin:/usr/sbin:/sbin) que excluye Homebrew (/opt/homebrew/bin)
-- y ~/.local/bin, así que un arg `claude` pelado falla al spawn. Sondeamos
-- las rutas absolutas habituales; como último recurso el nombre pelado
-- (que funciona en Windows + Linux donde claude está en el PATH heredado).
local function find_claude_bin()
  if wezterm.target_triple:find 'windows' then
    return 'claude'   -- el installer lo pone en el PATH; nada que sondear
  end
  local home = wezterm.home_dir
  local candidates = {
    home .. '/.claude/local/claude',  -- install recomendado por Anthropic
    home .. '/.local/bin/claude',     -- pip / install manual
    '/opt/homebrew/bin/claude',       -- macOS Apple Silicon brew
    '/usr/local/bin/claude',          -- macOS Intel brew / Linux genérico
    '/usr/bin/claude',                -- paquetes de distros Linux
  }
  for _, p in ipairs(candidates) do
    if file_exists(p) then return p end
  end
  return 'claude'   -- último recurso: confiar en el PATH
end

local AI = {
  LEFT_RATIO       = 0.65,                                    -- columna opus
  LEFT_TOP_RATIO   = 0.82,                                    -- cuota de opus en la columna izquierda
  RIGHT_TOP_RATIO  = 0.50,                                    -- sonnet vs haiku
  MODELS           = { tl = 'opus', tr = 'sonnet', br = 'haiku' },
  CLAUDE_BIN       = find_claude_bin(),
  -- Layout dedicado para la ventana de Modo IA en la pantalla principal.
  -- Origen = (LAYOUT_X, LAYOUT_Y) del tamaño de pantalla; tamaño =
  -- WIDTH x HEIGHT del tamaño de pantalla. Por defecto la pone centrada
  -- con márgenes 15%/10%.
  LAYOUT_X         = 0.15,
  LAYOUT_Y         = 0.10,
  LAYOUT_W         = 0.70,
  LAYOUT_H         = 0.80,
}

-- Set de window IDs (clave string) que pertenecen a Modo IA. El handler
-- window-resized de §6 los salta para que redimensionar una ventana de
-- Modo IA no sobrescriba la geometría guardada que usan las ventanas
-- normales.
local ai_mode_windows = {}

-- Coloca la ventana recién spawneada de Modo IA en su layout dedicado
-- sobre la pantalla principal, ignorando la geometría guardada. Replica
-- el patrón de defer de apply_saved_size_to: intenta sync, reintenta
-- una vez vía call_after si gui_window() es nil.
local function apply_ai_mode_layout(mux_window)
  local screens = wezterm.gui.screens()
  local s = screens and (screens.main or screens.active)
  if not s then return end
  local w = math.floor(s.width  * AI.LAYOUT_W)
  local h = math.floor(s.height * AI.LAYOUT_H)
  local x = s.x + math.floor(s.width  * AI.LAYOUT_X)
  local y = s.y + math.floor(s.height * AI.LAYOUT_Y)
  local function apply()
    local g = mux_window:gui_window()
    if not g then return end
    g:set_inner_size(w, h)
    g:set_position(x, y)
  end
  if mux_window:gui_window() then apply()
  else wezterm.time.call_after(0.05, apply) end
end

-- Resuelve el CWD de `pane` entre SO / shells.
-- Orden: OSC 7 (Url.file_path) → foreground process info → home dir.
local function pane_cwd(pane)
  local url = pane:get_current_working_dir()
  if url and url.file_path then
    local p = url.file_path
    -- Windows: Url.file_path puede llegar como "/C:/Users/..." (PS7 y
    -- shells nativos Windows) o "/c/Users/..." (Git Bash / MSYS, cuando
    -- el OSC-7 emite ${PWD} crudo). Normalizamos ambos a "C:/Users/..."
    -- para que mux.spawn_window y pane:split puedan pasarlo a procesos
    -- nativos Windows como claude.exe.
    if wezterm.target_triple:find 'windows' then
      p = p:gsub('^/([A-Za-z]:)', '%1')
      p = p:gsub('^/([A-Za-z])/', function(d) return d:upper() .. ':/' end)
    end
    return p
  end
  local info = pane:get_foreground_process_info()
  if info and info.cwd and info.cwd ~= '' then
    return info.cwd
  end
  return wezterm.home_dir
end

-- Construye el layout de 4 panes en una ventana NUEVA, anclada al CWD del
-- source pane. Orden de splits (sigue la lógica del aimode.py de iTerm):
--   1. spawn_window      → ventana nueva, top-left = opus
--   2. tl:split Right    → crea la columna derecha (sonnet arriba)
--   3. tl:split Bottom   → splittea la columna IZQUIERDA → tira de shell bajo opus
--   4. tr:split Bottom   → splittea la columna DERECHA → haiku bajo sonnet
-- Los pasos 3 y 4 splittean parents distintos, así que las columnas
-- izquierda y derecha acaban con divisores horizontales independientes
-- (dimensionados por LEFT_TOP_RATIO y RIGHT_TOP_RATIO respectivamente).
local function open_ai_mode(_window, source_pane)
  local cwd = pane_cwd(source_pane)
  -- Compone los args para `claude`: bin + extras de §0 + --model X.
  -- Los extras se insertan antes de --model para no romper el caso en
  -- que `claude` deje de aceptar flags después del último argumento
  -- posicional en versiones futuras.
  local claude_args = function(model)
    local args = { AI.CLAUDE_BIN }
    for _, extra in ipairs(CUSTOMIZE.CLAUDE_EXTRA_ARGS) do
      table.insert(args, extra)
    end
    table.insert(args, '--model')
    table.insert(args, model)
    return args
  end

  -- 1. Ventana nueva con opus como pane inicial.
  local _tab, tl, ai_mux = mux.spawn_window {
    args = claude_args(AI.MODELS.tl),
    cwd  = cwd,
  }

  -- Modo IA usa su propio layout dedicado en vez de la geometría guardada
  -- — un % fijo de la pantalla principal, centrado. Marcamos la ventana
  -- para que el window-resized de §6 no guarde los resizes de Modo IA
  -- pisando el tamaño de tus ventanas normales. Los splits de abajo se
  -- mantienen ratio-based, así el layout escala limpio.
  if ai_mux then
    ai_mode_windows[tostring(ai_mux:window_id())] = true
    apply_ai_mode_layout(ai_mux)
  end

  -- 2. Columna derecha (sonnet); size = cuota de la columna derecha = 1 - LEFT_RATIO.
  local tr = tl:split {
    direction = 'Right',
    size      = 1 - AI.LEFT_RATIO,
    args      = claude_args(AI.MODELS.tr),
    cwd       = cwd,
  }

  -- 3. Tira de shell bajo opus; size = cuota inferior de la columna IZQUIERDA.
  tl:split {
    direction = 'Bottom',
    size      = 1 - AI.LEFT_TOP_RATIO,
    cwd       = cwd,
    -- sin args ⇒ usa config.default_prog de §2
  }

  -- 4. Haiku bajo sonnet; size = cuota inferior de la columna DERECHA.
  tr:split {
    direction = 'Bottom',
    size      = 1 - AI.RIGHT_TOP_RATIO,
    args      = claude_args(AI.MODELS.br),
    cwd       = cwd,
  }

  tl:activate()
end


-- ─── §5  Funcionalidad: Shell profile picker (sólo Windows) ────────────────
--
-- Click en "+" o pulsa CTRL+SHIFT+T para abrir un fuzzy picker; el perfil
-- elegido spawnea una VENTANA NUEVA con su propio color scheme aplicado.
--
-- ¿Por qué hardcoded? Drafts antiguos leían settings.json de Windows
-- Terminal en cada arranque para mirroreo de los perfiles WT del usuario.
-- Funcionaba pero ataba esta config a cualquier estado en que estuviese
-- WT en ese momento (no idempotente: edits en WT cambiaban silenciosamente
-- el comportamiento de WezTerm). Ahora este fichero es la única fuente
-- de verdad; la misma config produce el mismo comportamiento en cualquier
-- máquina y se distribuye sin cambios vía el installer de devcli.
--
-- "Ventana nueva por perfil" es necesario porque WezTerm scopa los color
-- scheme overrides a la ventana GUI, no a la pestaña. Para que las
-- pestañas compartan un único scheme, sustituye mux.spawn_window por
-- mux_window:spawn_tab del active window en el callback del picker.
--
-- Para añadir / cambiar perfiles: edita `schemes` y `profiles` abajo. El
-- orden de `profiles` es el orden en que el picker los muestra.

-- Color de las líneas divisoras
local pane_split_color = '#a04e18'

-- Mantén los colores intactos cuando otra ventana/pane gana foco; el default
-- de WezTerm atenúa panes inactivos y vuelve las divisorias a gris.
config.inactive_pane_hsb = {
  saturation = 1.0,
  brightness = 1.0,
}

if wezterm.target_triple:find 'windows' then
  local function builtin_scheme_with_split(name)
    local builtin = wezterm.color.get_builtin_schemes()[name] or {}
    local scheme = {}
    for key, value in pairs(builtin) do
      scheme[key] = value
    end
    scheme.split = pane_split_color
    return scheme
  end

  -- Color schemes hardcoded (paletas canónicas de Microsoft Console + Ubuntu).
  -- Disponibles globalmente vía config.color_scheme y por-ventana vía
  -- mux_window:gui_window():set_config_overrides{ color_scheme = '…' }.
  local schemes = {
    -- Overrides local del scheme bundled para conservar Git Bash con los
    -- mismos colores, pero con divisorias naranja.
    ['iTerm2 Dark Background'] = builtin_scheme_with_split('iTerm2 Dark Background'),

    -- Git Bash — fg #BFBFBF sobre negro; la paleta que el usuario mantenía
    -- en el settings.json de WT (verbatim).
    ['LP-GitBash'] = {
      foreground    = '#BFBFBF', background = '#110c12',
      split = pane_split_color,
      cursor_bg     = '#FFFFFF', cursor_fg  = '#000000',
      cursor_border = '#FFFFFF',
      selection_bg  = '#FFFFFF', selection_fg = '#000000',
      ansi    = { '#0C0C0C', '#BF0000', '#00A400', '#BFBF00',
                  '#6060FF', '#BF00BF', '#3A96DD', '#FFFFFF' },
      brights = { '#767676', '#E74856', '#16C60C', '#F9F1A5',
                  '#3b78ff', '#B4009E', '#61D6D6', '#F2F2F2' },
    },
    -- Microsoft Console default — usado por PowerShell 7 y cmd.exe.
    ['LP-Campbell'] = {
      foreground    = '#CCCCCC', background = '#0C0C0C',
      split = pane_split_color,
      cursor_bg     = '#FFFFFF', cursor_fg  = '#0C0C0C',
      cursor_border = '#FFFFFF',
      selection_bg  = '#FFFFFF', selection_fg = '#000000',
      ansi    = { '#0C0C0C', '#C50F1F', '#13A10E', '#C19C00',
                  '#0037DA', '#881798', '#3A96DD', '#CCCCCC' },
      brights = { '#767676', '#E74856', '#16C60C', '#F9F1A5',
                  '#3B78FF', '#B4009E', '#61D6D6', '#F2F2F2' },
    },
    -- Microsoft Console (PowerShell 5) — misma paleta que Campbell con
    -- el icónico fondo azul.
    ['LP-Campbell Powershell'] = {
      foreground    = '#CCCCCC', background = '#012456',
      split = pane_split_color,
      cursor_bg     = '#FFFFFF', cursor_fg  = '#012456',
      cursor_border = '#FFFFFF',
      selection_bg  = '#FFFFFF', selection_fg = '#000000',
      ansi    = { '#0C0C0C', '#C50F1F', '#13A10E', '#C19C00',
                  '#0037DA', '#881798', '#3A96DD', '#CCCCCC' },
      brights = { '#767676', '#E74856', '#16C60C', '#F9F1A5',
                  '#3B78FF', '#B4009E', '#61D6D6', '#F2F2F2' },
    },
    -- Paleta estándar del Ubuntu Terminal (derivada de Tango) — usada por WSL.
    ['LP-Ubuntu'] = {
      foreground    = '#BFBFBF', background = '#300A24',
      split = pane_split_color,
      cursor_bg     = '#BFBFBF', cursor_fg  = '#300A24',
      cursor_border = '#BFBFBF',
      selection_bg  = '#B5D5FF', selection_fg = '#000000',
      ansi    = { '#2E3436', '#CC0000', '#4E9A06', '#C4A000',
                  '#3465A4', '#75507B', '#06989A', '#D3D7CF' },
      brights = { '#555753', '#EF2929', '#8AE234', '#FCE94F',
                  '#729FCF', '#AD7FA8', '#34E2E2', '#EEEEEC' },
    },
  }

  -- Inyectamos los schemes en config.color_schemes para que
  -- set_config_overrides pueda referenciarlos por nombre.
  config.color_schemes = config.color_schemes or {}
  for name, scheme in pairs(schemes) do
    config.color_schemes[name] = scheme
  end

  -- Lista de perfiles hardcoded. El orden importa — el picker los muestra
  -- de arriba abajo en este orden exacto, con shortcuts numéricos 1-5.
  local prog_files = os.getenv('ProgramFiles') or 'C:\\Program Files'
  local sys_root   = os.getenv('SystemRoot')   or 'C:\\Windows'
  local home       = os.getenv('USERPROFILE')

  local profiles = {
    {
      label        = 'Git Bash',
      args         = { prog_files .. '\\Git\\bin\\bash.exe', '--login', '-i', '-l' },
      cwd          = home,
      -- color_scheme = 'iTerm2 Dark Background',
      color_scheme = 'LP-GitBash',
    },
    {
      label        = 'PowerShell 7',
      args         = { 'pwsh.exe' },
      cwd          = nil,
      color_scheme = 'LP-Campbell',
    },
    -- PowerShell 7 elevado (UAC).
    --
    -- Restricción arquitectural: una WezTerm no-elevada NO puede hostear
    -- un proceso elevado dentro de un pane (Windows bloquea la I/O entre
    -- procesos con distintos niveles de integridad — UIPI). Misma razón
    -- por la que Windows Terminal abre una NUEVA ventana WT elevada al
    -- elegir un perfil "as administrator".
    --
    -- Solución: lanzamos `Start-Process -Verb RunAs` como CHILD del propio
    -- wezterm-gui (vía wezterm.background_child_process en el callback del
    -- picker, marcado con `elevated = true`), NO como pane. El flow:
    --
    --   1. background_child_process arranca powershell.exe oculto
    --      (-WindowStyle Hidden) sin crear ningún pane WezTerm.
    --   2. powershell.exe corre Start-Process -Verb RunAs → UAC prompt.
    --   3. Si el usuario acepta, arranca wezterm-gui.exe elevado, que
    --      lee este mismo wezterm.lua y abre una ventana con pwsh.
    --   4. powershell.exe sale; al no haber pane ni ventana host, no hay
    --      flash de una ventana WezTerm intermedia abriéndose y cerrándose.
    --
    -- (Versión anterior usaba mux.spawn_window con powershell.exe como
    -- arg, que creaba una ventana WezTerm no-elevada efímera para hostear
    -- el launcher. Funcionaba pero parpadeaba visiblemente entre el click
    -- y la ventana elevada — la razón de pasar a background_child_process.)
    --
    -- Resultado neto: un click → UAC → ventana wezterm elevada con PS7,
    -- con el mismo theme, key bindings y workflows que las normales.
    -- Si el usuario cancela el UAC, powershell sale igualmente sin
    -- side-effects.
    --
    -- Requiere `wezterm-gui.exe` en el PATH (lo añade el shim de scoop
    -- en instalaciones devcli; si falta, ajusta la ruta absoluta).
    {
      label        = 'PowerShell 7 (admin)',
      elevated     = true,
      args         = {
        'powershell.exe', '-NoProfile', '-WindowStyle', 'Hidden', '-Command',
        "Start-Process -FilePath wezterm-gui -ArgumentList 'start','--','pwsh.exe' -Verb RunAs",
      },
      cwd          = nil,
      -- Sólo informativo: el wezterm-gui elevado lee este mismo fichero y
      -- aplica `LP-Campbell` automáticamente vía exe_to_scheme (pwsh.exe).
      color_scheme = 'LP-Campbell',
    },
    {
      label        = 'Ubuntu',
      args         = { 'wsl.exe', '-d', 'Ubuntu-24.04' },
      cwd          = nil,
      color_scheme = 'LP-Ubuntu',
    },
    {
      label        = 'CMD',
      args         = {
        sys_root .. '\\System32\\cmd.exe',
        '/k',
        (home or '') .. '\\cmd_aliases.cmd',
      },
      cwd          = home,
      color_scheme = 'LP-Campbell',
    },
    {
      label        = 'PowerShell 5',
      args         = {
        sys_root .. '\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
      },
      cwd          = nil,
      color_scheme = 'LP-Campbell Powershell',
    },
  }

  -- Fija el scheme global por defecto para emparejar el shell elegido
  -- en §2, así la primera ventana (que spawnea config.default_prog, no
  -- vía picker) abre con los colores del shell en vez del fallback de §3.
  --       ['bash.exe']       = 'iTerm2 Dark Background',
  do
    local default_exe = exe_basename(config.default_prog and config.default_prog[1])
    local exe_to_scheme = {
      ['bash.exe']       = 'LP-GitBash',
      ['pwsh.exe']       = 'LP-Campbell',
      ['powershell.exe'] = 'LP-Campbell Powershell',
      ['cmd.exe']        = 'LP-Campbell',
      ['wsl.exe']        = 'LP-Ubuntu',
    } 
    -- Resolvemos contra TANTO los schemes inyectados del usuario (LP-*)
    -- COMO los ~960 bundled de WezTerm — si no, los nombres built-in
    -- silenciosamente fallan el check y la primera ventana cae al scheme
    -- default de §3.
    local function scheme_exists(name)
      return (config.color_schemes and config.color_schemes[name] ~= nil)
          or (wezterm.color.get_builtin_schemes()[name] ~= nil)
    end
    local default_scheme = exe_to_scheme[default_exe]
    if default_scheme and scheme_exists(default_scheme) then
      config.color_scheme = default_scheme
    end
  end

  -- Color-scheme overrides diferidos.
  --
  -- mux.spawn_window devuelve el MuxWindow nuevo de forma síncrona, pero
  -- la ventana GUI puede no estar realizada aún — mux_window:gui_window()
  -- devuelve nil. Cuando pasa eso, almacenamos aquí el scheme deseado,
  -- indexado por window id; el handler window-focus-changed de abajo lo
  -- aplica la primera vez que la ventana nueva recibe foco (lo que pasa
  -- justo después del spawn).
  local pending_scheme_by_window = {}

  -- Perfil que abrió cada ventana spawneada vía picker. Indexado por
  -- window id (string). Permite que CTRL+ALT+T (y la entrada "Tab" del
  -- picker) abra una pestaña nueva en la ventana actual usando el MISMO
  -- shell que la abrió. Las ventanas que NO están en este map (la primera
  -- ventana de config.default_prog, las ventanas de Modo IA) caen a
  -- spawnear la pestaña sin args, lo que usa config.default_prog de §2
  -- — Git Bash en esta máquina.
  local profile_by_window = {}

  -- Spawnea una pestaña nueva en la ventana del source pane. Si la
  -- ventana se abrió vía picker, reutiliza los args+cwd de ese perfil; si
  -- no, deja que WezTerm use config.default_prog. El color scheme se
  -- hereda de la ventana host (WezTerm scopa los color overrides
  -- por-ventana, no por-pestaña).
  spawn_tab_same_shell = function(window, _pane)
    local mux_w = window:mux_window()
    if not mux_w then return end
    local prof = profile_by_window[tostring(mux_w:window_id())]
    local spawn = {}
    if prof then
      spawn.args = prof.args
      spawn.cwd  = prof.cwd
    end
    mux_w:spawn_tab(spawn)
  end

  -- Tabla espejo del exe_to_scheme de §3. Mantén ambas en sync — si añades
  -- un shell nuevo a una, añádelo a la otra. La de §3 fija el scheme global
  -- en la PRIMERA ventana (basado en config.default_prog); ésta lo aplica
  -- por-ventana cuando una ventana gana foco y su pane activo está
  -- ejecutando un exe conocido. El resultado es que las ventanas spawneadas
  -- FUERA del picker (gitbox, `wezterm cli spawn`, doble-click en
  -- WezTerm.app desde Finder, etc.) también reciben el color scheme del
  -- shell que están hospedando — el picker callback ya lo hace por su
  -- camino vía pending_scheme_by_window.
  local exe_to_scheme_runtime = {
    ['bash.exe']       = 'LP-GitBash',
    ['pwsh.exe']       = 'LP-Campbell',
    ['powershell.exe'] = 'LP-Campbell Powershell',
    ['cmd.exe']        = 'LP-Campbell',
    ['wsl.exe']        = 'LP-Ubuntu',
  }

  wezterm.on('window-focus-changed', function(win, pane)
    local key = tostring(win:window_id())

    -- 1. Prioridad: scheme diferido por el picker (§5 mux.spawn_window).
    local pending = pending_scheme_by_window[key]
    if pending then
      local overrides = win:get_config_overrides() or {}
      if overrides.color_scheme ~= pending then
        overrides.color_scheme = pending
        win:set_config_overrides(overrides)
      end
      pending_scheme_by_window[key] = nil
      return
    end

    -- 2. Fallback: aplica el scheme correspondiente al exe en primer plano
    -- del pane activo. Cubre ventanas que NO pasaron por el picker (gitbox
    -- launch, `wezterm cli spawn`, etc.) — el shell todavía recibe colores
    -- consistentes con la convención de §3.
    --
    -- Limitación conocida: WezTerm scopa color_scheme POR VENTANA, no por
    -- pestaña/pane. Si una ventana hosta pestañas con shells distintos,
    -- el scheme de la ventana refleja el exe del pane FOCUSEADO cuando la
    -- ventana ganó foco, no necesariamente el de la pestaña que mires
    -- después.
    if not pane then return end
    local proc = pane:get_foreground_process_name() or ''
    -- Saca el basename y normaliza minúsculas: get_foreground_process_name
    -- devuelve la ruta completa en Windows (C:\Program Files\PowerShell\7\
    -- pwsh.exe) y a veces sólo el nombre en Unix.
    local exe = string.lower(proc:match('([^\\/]+)$') or '')
    local new_scheme = exe_to_scheme_runtime[exe]
    if not new_scheme then return end
    local overrides = win:get_config_overrides() or {}
    if overrides.color_scheme ~= new_scheme then
      overrides.color_scheme = new_scheme
      win:set_config_overrides(overrides)
    end
  end)

  -- El picker: construye choices en el orden declarado, muestra el
  -- InputSelector, y al seleccionar spawnea una ventana nueva y aplica
  -- el color scheme por-ventana. La ÚLTIMA entrada es especial: "Tab"
  -- se queda en esta ventana y spawnea una pestaña con el mismo shell
  -- (delega en spawn_tab_same_shell de arriba).
  show_profile_picker = function(window, pane)
    local choices = {}
    for i, p in ipairs(profiles) do
      table.insert(choices, { id = tostring(i), label = p.label })
    end
    table.insert(choices, {
      id    = 'tab',
      label = 'Tab in this window (same shell)',
    })

    window:perform_action(act.InputSelector {
      title       = 'Open a shell',
      description = 'Pick a profile (new window) or "Tab" (current window, same shell).',
      fuzzy       = true,
      choices     = choices,
      action = wezterm.action_callback(function(_win, _pn, id, _label)
        if not id then return end             -- cancelado (Esc)

        -- Rama "Tab": spawnea en la ventana actual, reutilizando shell.
        if id == 'tab' then
          spawn_tab_same_shell(window, pane)
          return
        end

        local idx = tonumber(id)
        local prof = idx and profiles[idx]
        if not prof then return end

        -- Perfil elevado (admin): NO creamos pane/ventana WezTerm para
        -- hostear el launcher — eso producía la ventana que parpadeaba
        -- antes de aparecer la elevada. background_child_process spawnea
        -- powershell oculto como hijo del wezterm-gui actual; el flow de
        -- elevación corre sin UI intermedia y la ventana wezterm-gui
        -- elevada (proceso independiente) abre directamente. Saltamos el
        -- resto del callback porque no hay new_mux sobre el que aplicar
        -- color override ni profile_by_window.
        if prof.elevated then
          wezterm.background_child_process(prof.args)
          return
        end

        local _tab, _new_pane, new_mux = mux.spawn_window {
          args = prof.args,
          cwd  = prof.cwd,
        }

        -- Empareja la geometría guardada para que las ventanas spawneadas
        -- vía picker abran al tamaño preferido del usuario (ver §6).
        if new_mux then apply_saved_size_to(new_mux) end

        -- Recordamos qué perfil abrió esta ventana, así CTRL+ALT+T desde
        -- cualquier pane suyo sabe qué shell duplicar en una pestaña nueva.
        if new_mux then
          profile_by_window[tostring(new_mux:window_id())] = prof
        end

        -- Aplica el color scheme override por-ventana. Intenta sync
        -- primero; si la ventana GUI no está realizada aún, defer al
        -- handler window-focus-changed de arriba (que aplica en cuanto
        -- la ventana recibe foco).
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

  -- Botón "+" de pestañas → muestra el picker en vez del "new tab" default.
  wezterm.on('new-tab-button-click', function(window, pane, button, _default)
    if button == 'Left' and show_profile_picker then
      show_profile_picker(window, pane)
      return false   -- suprime el comportamiento default de new-tab
    end
  end)
end


-- ─── §6  Funcionalidad: Window state persistence ───────────────────────────
--
-- Guarda el tamaño en píxeles y el estado fullscreen de la última ventana
-- en cada resize, y los restaura al arrancar. La primera ventana de cada
-- arranque se centra en la pantalla principal — WezTerm expone
-- window:set_position() pero NO tiene getter para position, así que no
-- podemos restaurar dónde estaba la ventana arrastrada; el centrado da
-- un punto de partida determinista y predecible en vez de depender de
-- lo que el SO decida.
--
-- Fichero de estado: <wezterm.config_dir>/window_state.json
--   { "pixel_width": N, "pixel_height": N, "is_full_screen": bool }
--
-- Nota: Modo IA (§4) y el shell picker (§5) también spawnean ventanas vía
-- mux.spawn_window, así que window-resized se dispara para ellas también
-- y sobrescribe la geometría guardada. Aceptable para v1 — si te molesta,
-- scopa el guardado a "sólo primera ventana" vía un allow-list de window-id.

local STATE_FILE = wezterm.config_dir .. '/window_state.json'

local function read_window_state()
  local f = io.open(STATE_FILE, 'r')
  if not f then return nil end
  local raw = f:read('*a')
  f:close()
  local ok, state = pcall(wezterm.json_parse, raw)
  if not ok then return nil end
  return state
end

local function write_window_state(state)
  local f = io.open(STATE_FILE, 'w')
  if not f then return end
  f:write(wezterm.json_encode(state))
  f:close()
end

-- Aplica el tamaño en píxeles guardado a un MuxWindow recién spawneado.
-- Lo usan §4 (Modo IA) y §5 (shell picker) para que cada ventana nueva
-- herede el mismo tamaño que la primera. Devuelve (w, h) que programó
-- aplicar, o nil si no hay un estado guardado válido.
--
-- gui_window() puede devolver nil justo después de mux.spawn_window (la
-- ventana GUI no está realizada aún); cuando pasa, reintenta una vez
-- vía call_after.
apply_saved_size_to = function(mux_window)
  local state = read_window_state()
  if not state
     or not state.pixel_width or not state.pixel_height
     or state.pixel_width  <= 200
     or state.pixel_height <= 100 then
    return nil
  end
  local w, h = state.pixel_width, state.pixel_height
  local function set_now()
    local g = mux_window:gui_window()
    if g then g:set_inner_size(w, h) end
  end
  local gui = mux_window:gui_window()
  if gui then
    gui:set_inner_size(w, h)
  else
    wezterm.time.call_after(0.05, set_now)
  end
  return w, h
end

-- Se dispara en drag-resize, maximize/restore, y toggle de fullscreen.
-- WezTerm coalesce este evento (1 ejecutándose + 1 en cola), pero la I/O
-- síncrona a disco sigue ocurriendo en el hilo de UI: en Windows,
-- `io.open`+`close` sobre el JSON puede tardar 10-50 ms cuando
-- Defender/AV escanea el archivo recién escrito, lo que produce los
-- saltos visibles al redimensionar arrastrando rápido (macOS/Linux no
-- tienen ese coste por escritura).
--
-- Solución: debounce. Cada evento sólo registra la última geometría y
-- programa una escritura diferida 250 ms después; si llega otro resize
-- antes, el contador de generación invalida la escritura pendiente y sólo
-- la última (cuando el usuario suelta y todo queda quieto) toca disco.
--
-- Saltamos Modo IA (§4) para que su layout dedicado no sobrescriba la
-- geometría guardada de las ventanas normales.
local resize_save_gen = 0

wezterm.on('window-resized', function(window, _pane)
  local mux_w = window:mux_window()
  if mux_w and ai_mode_windows[tostring(mux_w:window_id())] then
    return
  end
  local dims = window:get_dimensions()
  if not dims then return end

  resize_save_gen = resize_save_gen + 1
  local my_gen = resize_save_gen
  local snapshot = {
    pixel_width    = dims.pixel_width,
    pixel_height   = dims.pixel_height,
    is_full_screen = dims.is_full_screen,
  }
  wezterm.time.call_after(0.25, function()
    if resize_save_gen == my_gen then
      write_window_state(snapshot)
    end
  end)
end)

-- Se dispara una vez antes de que exista ninguna ventana. Spawneamos
-- nosotros la ventana inicial para poder aplicarle la geometría guardada
-- vía gui_window(). Después, antes de devolver el control a WezTerm, la
-- centramos en la pantalla principal.
wezterm.on('gui-startup', function(cmd)
  local _tab, _pane, mux_window = mux.spawn_window(cmd or {})
  local gui = mux_window:gui_window()
  if not gui then return end

  -- Aplica el tamaño guardado (mismo path que §4 / §5 para ventanas
  -- nuevas). Cae a lo que WezTerm escogió desde initial_cols/initial_rows
  -- en §3.
  local target_w, target_h = apply_saved_size_to(mux_window)
  if not target_w then
    local dims = gui:get_dimensions()
    target_w = dims and dims.pixel_width  or 1600
    target_h = dims and dims.pixel_height or 900
  end

  local state = read_window_state()

  -- Centra en la pantalla principal. Usamos "main" en vez de "active"
  -- porque en gui-startup ninguna ventana GUI ha renderizado aún, así que
  -- "active" es ambiguo; "main" es el display primario del SO, que es
  -- determinista. set_position toma coordenadas de outer-window; centrar
  -- por inner size se desfasa ~la altura de la title bar, pero son
  -- píxeles y no se nota. No-op en Wayland (set_position no soportado
  -- ahí); cae a lo que el compositor decida, que está bien.
  local screens = wezterm.gui.screens()
  local s = screens and (screens.main or screens.active)
  if s then
    local x = s.x + math.max(0, math.floor((s.width  - target_w) / 2))
    local y = s.y + math.max(0, math.floor((s.height - target_h) / 2))
    gui:set_position(x, y)
  end

  if state and state.is_full_screen then
    -- maximize() pisa la posición centrada; es intencional — restaurar
    -- "la última estaba maximizada" gana al centrado.
    gui:maximize()
  end
end)


-- ─── §7  Key bindings ──────────────────────────────────────────────────────
--
-- Convenciones de modificadores por SO (la super-config elige el adecuado):
--   Windows : CTRL|ALT  — WIN+N lo agarra el Notification Center.
--   macOS   : CTRL|SUPER (= CTRL|CMD) — ALT+N produce la dead-key `~`.
--   Linux   : CTRL|SUPER — Super es la tecla Win, libre en DEs estándar.
-- Los hotkeys disparan desde cualquier pane. Añade nuevos hotkeys de
-- funcionalidades a esta tabla.

local ai_mode_mods = wezterm.target_triple:find 'windows' and 'CTRL|ALT'
                  or 'CTRL|SUPER'

local key_bindings = {
  -- Modo IA (§4): workspace de cuatro panes con Claude anclado al CWD actual.
  {
    key    = 'n',
    mods   = ai_mode_mods,
    action = wezterm.action_callback(open_ai_mode),
  },
  -- Theme picker (§3): preview fuzzy sobre cada color scheme bundled.
  -- Cross-platform; override scopado a la ventana, no modifica este fichero.
  {
    key    = 'e',
    mods   = 'CTRL|SHIFT',
    action = wezterm.action_callback(show_theme_picker),
  },
}

-- Shell picker (§5): alternativa de teclado a clickear en "+".
-- CTRL+SHIFT+T → picker (ventana nueva).
-- CTRL+ALT+T   → pestaña en la ventana actual con el mismo shell que la
--                abrió (ver spawn_tab_same_shell en §5).
if show_profile_picker then
  table.insert(key_bindings, {
    key    = 't',
    mods   = 'CTRL|SHIFT',
    action = wezterm.action_callback(show_profile_picker),
  })
  table.insert(key_bindings, {
    key    = 't',
    mods   = 'CTRL|ALT',
    action = wezterm.action_callback(spawn_tab_same_shell),
  })
end

config.keys = key_bindings


-- ─── §8  Mouse bindings ────────────────────────────────────────────────────
--
-- Click derecho estilo Windows Terminal:
--   • Si hay texto seleccionado, el click derecho lo copia (y limpia la
--     selección).
--   • Si no hay nada seleccionado, el click derecho pega del clipboard.
-- Esto sobrescribe el click derecho default de WezTerm (que es "extender
-- selección").

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
