-- ════════════════════════════════════════════════════════════════════════════
-- custom_keys.lua — personalización de atajos de WezTerm (ranura de devcli)
--
-- wezterm.lua es idéntico en todas las máquinas y, al final (§9), carga este
-- fichero si existe en la misma carpeta. El contrato es mínimo: devolver una
-- tabla con una función apply(config). Aquí puedes poner TUS atajos.
--
-- Lo que trae devcli de serie (bootstrap.ps1 -CustomKeys on, sólo Windows) es
-- la mitad WezTerm de la capa «teclado de PC como un Mac»: atajos de fábrica
-- de iTerm2 con Alt izquierdo en el papel de Cmd. La otra mitad es el mapa
-- de PowerToys Keyboard Manager, custom_keys.powertoys.json. Van en pareja:
--
--   • Dentro de WezTerm, PowerToys convierte Cmd+tecla en F13–F24 o
--     Shift+F13–F24 (teclas que el teclado no tiene), y la tabla de abajo da
--     una acción a cada una. Así no chocan con los caracteres de control
--     (Cmd+C nunca envía SIGINT) ni con los CTRL+SHIFT de wezterm.lua.
--   • Con PowerToys y sin este fichero, Cmd+C en WezTerm no hace nada.
--     Con este fichero y sin PowerToys, nunca llega ninguna F13–F24.
--
-- Cómo personalizarlo:
--   • Edítalo a tu gusto. devcli recuerda lo que desplegó y, si lo cambias,
--     no lo vuelve a pisar (te avisa; -CustomKeys force lo reescribe).
--   • Para no usar nada, déjalo así:  return { apply = function() end }
--   • Fuera de Windows este módulo no hace nada (en macOS Cmd ya es SUPER).
--
-- Mapa completo y limitaciones: docs/teclado-mac.md en el repo de devcli.
-- ════════════════════════════════════════════════════════════════════════════

local wezterm = require 'wezterm'
local act = wezterm.action

local M = {}

local select_all = act.Multiple {
  act.ActivateCopyMode,
  act.CopyMode 'MoveToScrollbackTop',
  act.CopyMode { SetSelectionMode = 'Cell' },
  act.CopyMode 'MoveToScrollbackBottom',
  act.CopyMode 'MoveToEndOfLineContent',
}

-- ─── Igualado de paneles ───────────────────────────────────────────────────
--
-- WezTerm no trae una acción «igualar paneles», y cada panel sólo puede mover
-- su divisor más cercano en una dirección. Así que cada divisor se mueve a
-- través del panel que resulte controlarlo.
local AXES = {
  x = { pos = 'left', size = 'width', cross_pos = 'top', cross_size = 'height', grow = 'Right', shrink = 'Left' },
  y = { pos = 'top', size = 'height', cross_pos = 'left', cross_size = 'width', grow = 'Down', shrink = 'Up' },
}

-- Las columnas (eje x) o filas (eje y) alineadas con el panel, en orden.
local function tracks_for(tab, axis, pane_id)
  local info = tab:panes_with_info()
  local active
  for _, p in ipairs(info) do
    if p.pane:pane_id() == pane_id then active = p end
  end
  if not active then return nil end

  local by_key, tracks = {}, {}
  for _, p in ipairs(info) do
    local overlaps = p[axis.cross_pos] < active[axis.cross_pos] + active[axis.cross_size]
      and active[axis.cross_pos] < p[axis.cross_pos] + p[axis.cross_size]
    if overlaps then
      local key = p[axis.pos] .. ':' .. p[axis.size]
      if not by_key[key] then
        by_key[key] = { pos = p[axis.pos], size = p[axis.size], panes = {} }
        table.insert(tracks, by_key[key])
      end
      table.insert(by_key[key].panes, p.pane)
    end
  end
  table.sort(tracks, function(a, b) return a.pos < b.pos end)

  -- Las columnas que sólo se solapan en parte no tienen un tamaño común que igualar.
  for i = 2, #tracks do
    if tracks[i - 1].pos + tracks[i - 1].size + 1 ~= tracks[i].pos then return nil end
  end
  return tracks
end

local function divider_positions(tracks)
  local positions = {}
  for i = 1, #tracks - 1 do positions[i] = tracks[i].pos + tracks[i].size end
  return positions
end

-- Devuelve false si ningún panel controla este divisor. Pasa cuando sus dos
-- lados ya están divididos: WezTerm no ofrece forma de moverlo.
local function move_divider(window, tab, axis, pane_id, index, delta)
  local before = tracks_for(tab, axis, pane_id)
  if not before or not before[index + 1] then return false end
  local start = divider_positions(before)

  local candidates = {}
  for _, track in ipairs { before[index], before[index + 1] } do
    for _, pane in ipairs(track.panes) do table.insert(candidates, pane) end
  end
  for i, track in ipairs(before) do
    if i ~= index and i ~= index + 1 then
      for _, pane in ipairs(track.panes) do table.insert(candidates, pane) end
    end
  end

  local function adjust(pane, amount)
    pane:activate()
    local direction = amount > 0 and axis.grow or axis.shrink
    window:perform_action(act.AdjustPaneSize { direction, math.abs(amount) }, pane)
  end

  for _, pane in ipairs(candidates) do
    adjust(pane, delta)
    local after = tracks_for(tab, axis, pane_id)
    if not after or #after ~= #before then return false end
    local moved = divider_positions(after)
    if moved[index] ~= start[index] then return true end
    for i = 1, #start do
      if moved[i] ~= start[i] then
        adjust(pane, start[i] - moved[i]) -- este panel controla otro divisor: se deshace
        break
      end
    end
  end
  return false
end

-- Dónde debe quedar cada divisor para que las pistas entre dos divisores
-- fijos se repartan el espacio por igual.
local function divider_targets(tracks, fixed)
  local targets = {}
  local first = 1
  while first <= #tracks do
    local last = first
    while last < #tracks and not fixed[last] do last = last + 1 end
    local count = last - first + 1
    local origin = tracks[first].pos
    local total = tracks[last].pos + tracks[last].size - origin - (count - 1)
    local size, extra = math.floor(total / count), total % count
    for i = 1, count - 1 do
      targets[first + i - 1] = origin + i * size + math.min(i, extra) + (i - 1)
    end
    first = last + 1
  end
  return targets
end

local function equalize(window, tab, axis, pane_id)
  local fixed = {}
  -- Mover un divisor puede quedar limitado por su vecino: hace falta más de una pasada.
  for _ = 1, 8 do
    local tracks = tracks_for(tab, axis, pane_id)
    if not tracks or #tracks < 2 then return end
    local pending = false
    for i = 1, #tracks - 1 do
      local current = tracks_for(tab, axis, pane_id)
      if not current or #current ~= #tracks then return end
      local delta = (divider_targets(current, fixed)[i] or 0) - (current[i].pos + current[i].size)
      if not fixed[i] and delta ~= 0 then
        pending = true
        if not move_divider(window, tab, axis, pane_id, i, delta) then
          fixed[i] = true
        end
      end
    end
    if not pending then return end
  end
end

-- Un divisor con paneles divididos a ambos lados ya no se puede mover, así
-- que los divisores van a su sitio final mientras el panel activo sigue entero.
local function prepare_split(window, tab, axis, pane_id)
  local tracks = tracks_for(tab, axis, pane_id)
  if not tracks then return end
  local active_track
  for i, track in ipairs(tracks) do
    for _, pane in ipairs(track.panes) do
      if pane:pane_id() == pane_id then active_track = i end
    end
  end
  if not active_track then return end

  local count = #tracks + 1
  local origin = tracks[1].pos
  local total = tracks[#tracks].pos + tracks[#tracks].size - origin - (count - 1)
  local size, extra = math.floor(total / count), total % count
  for _ = 1, 3 do
    for i = 1, #tracks - 1 do
      local current = tracks_for(tab, axis, pane_id)
      if not current then return end
      local slot = i < active_track and i or i + 1
      local target = origin + slot * size + math.min(slot, extra) + (slot - 1)
      local delta = target - (current[i].pos + current[i].size)
      if delta ~= 0 then move_divider(window, tab, axis, pane_id, i, delta) end
    end
  end
end

-- Cmd+D y Cmd+Shift+D: divide y deja del mismo tamaño todas las columnas o
-- filas alineadas.
function M.split(window, pane, direction)
  local tab = window:active_tab()
  prepare_split(window, tab, AXES[direction], pane:pane_id())
  pane:activate()
  local split = direction == 'x' and act.SplitHorizontal { domain = 'CurrentPaneDomain' }
    or act.SplitVertical { domain = 'CurrentPaneDomain' }
  window:perform_action(split, pane)
  local new_pane = window:active_pane()
  equalize(window, tab, AXES[direction], new_pane:pane_id())
  new_pane:activate()
end

function M.split_equal(direction)
  return wezterm.action_callback(function(window, pane)
    M.split(window, pane, direction)
  end)
end

-- Cmd+W: WezTerm no avisa de cuándo se responde al «¿seguro?», así que se
-- vigila hasta 60 segundos a que desaparezca el panel y luego se igualan los
-- que quedan.
function M.close(window, pane)
  local tab = window:active_tab()
  local before = #tab:panes()
  window:perform_action(act.CloseCurrentPane { confirm = true }, pane)

  local tries = 0
  local function check()
    tries = tries + 1
    -- Cerrar el último panel elimina la pestaña o la ventana: no queda nada que igualar.
    local alive, count = pcall(function() return #tab:panes() end)
    if not alive or count == 0 then return end
    if count >= before then
      if tries < 240 then wezterm.time.call_after(0.25, check) end
      return
    end
    pcall(function()
      if window:active_tab():tab_id() ~= tab:tab_id() then return end
      local active = window:active_pane()
      equalize(window, tab, AXES.x, active:pane_id())
      equalize(window, tab, AXES.y, active:pane_id())
      active:activate()
    end)
  end
  wezterm.time.call_after(0.25, check)
end

-- ─── Tabla de atajos (contrato con custom_keys.powertoys.json) ─────────────

local keys = {
  -- F13–F23: Cmd+C V T W N D Shift+D F G Shift+G K
  { key = 'F13', action = act.CopyTo 'Clipboard' },
  { key = 'F14', action = act.PasteFrom 'Clipboard' },
  { key = 'F15', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'F16', action = wezterm.action_callback(M.close) },
  { key = 'F17', action = act.SpawnWindow },
  { key = 'F18', action = M.split_equal('x') },
  { key = 'F19', action = M.split_equal('y') },
  { key = 'F20', action = act.Search 'CurrentSelectionOrEmptyString' },
  { key = 'F23', action = act.Multiple {
      act.ClearScrollback 'ScrollbackAndViewport',
      act.SendKey { key = 'L', mods = 'CTRL' },
  } },
  -- El resto de Cmd+letra no hace nada, como en iTerm2.
  { key = 'F24', action = act.Nop },

  -- Shift+F13–F24: Cmd+A Q, flechas, Cmd+Option+flechas, Cmd+[ y Cmd+]
  { key = 'F13', mods = 'SHIFT', action = select_all },
  { key = 'F14', mods = 'SHIFT', action = act.QuitApplication },
  { key = 'F15', mods = 'SHIFT', action = act.ActivateTabRelative(-1) },
  { key = 'F16', mods = 'SHIFT', action = act.ActivateTabRelative(1) },
  { key = 'F17', mods = 'SHIFT', action = act.ScrollByLine(-1) },
  { key = 'F18', mods = 'SHIFT', action = act.ScrollByLine(1) },
  { key = 'F19', mods = 'SHIFT', action = act.ActivatePaneDirection 'Left' },
  { key = 'F20', mods = 'SHIFT', action = act.ActivatePaneDirection 'Right' },
  { key = 'F21', mods = 'SHIFT', action = act.ActivatePaneDirection 'Up' },
  { key = 'F22', mods = 'SHIFT', action = act.ActivatePaneDirection 'Down' },
  { key = 'F23', mods = 'SHIFT', action = act.ActivatePaneDirection 'Prev' },
  { key = 'F24', mods = 'SHIFT', action = act.ActivatePaneDirection 'Next' },

  -- Estos llegan de PowerToys sin cambio.
  { key = 'Enter', mods = 'ALT', action = act.ToggleFullScreen },
  { key = 'Enter', mods = 'ALT|SHIFT', action = act.TogglePaneZoomState },
  { key = 'LeftArrow', mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Left', 3 } },
  { key = 'RightArrow', mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Right', 3 } },
  { key = 'UpArrow', mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Up', 3 } },
  { key = 'DownArrow', mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Down', 3 } },
  { key = 'Home', mods = 'ALT', action = act.ScrollToTop },
  { key = 'End', mods = 'ALT', action = act.ScrollToBottom },
  { key = 'PageUp', mods = 'ALT', action = act.ScrollByPage(-1) },
  { key = 'PageDown', mods = 'ALT', action = act.ScrollByPage(1) },

  -- PowerToys los envía como Ctrl+tecla.
  { key = '+', mods = 'CTRL', action = act.IncreaseFontSize },
  { key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
  { key = '0', mods = 'CTRL', action = act.ResetFontSize },
}

for i = 1, 9 do
  table.insert(keys, { key = tostring(i), mods = 'CTRL', action = act.ActivateTab(i - 1) })
end

-- Cmd+G y Cmd+Shift+G sólo significan algo mientras se busca.
local search_keys = {
  { key = 'F21', action = act.CopyMode 'NextMatch' },
  { key = 'F22', action = act.CopyMode 'PriorMatch' },
}

-- WezTerm en Windows (al menos hasta 20240203) sólo reconoce hasta F20: F21–F24
-- le llegan como código crudo (VK 132–135) y `key = 'F21'` nunca coincide.
-- Cada atajo con F21–F24 se duplica con su `raw:<VK>`; si una versión futura
-- las reconoce, la entrada original sigue valiendo.
local function with_raw_twins(list)
  local out = {}
  for _, binding in ipairs(list) do
    table.insert(out, binding)
    local n = tonumber(binding.key:match '^F(2[1-4])$')
    if n then
      local twin = {}
      for k, v in pairs(binding) do twin[k] = v end
      twin.key = 'raw:' .. (111 + n)  -- VK_F21 = 0x84 = 132
      table.insert(out, twin)
    end
  end
  return out
end

function M.apply(config)
  -- La capa depende de PowerToys: fuera de Windows no hay nada que hacer.
  if not wezterm.target_triple:find 'windows' then return end

  config.keys = config.keys or {}
  for _, binding in ipairs(with_raw_twins(keys)) do
    table.insert(config.keys, binding)
  end

  -- Si wezterm.lua ya define key_tables se respetan y sólo se amplía
  -- search_mode. Si no, se parte de las de fábrica, que sólo existen con GUI
  -- (wezterm.gui es nil en `wezterm cli` o en el servidor mux).
  local tables = config.key_tables
  if not tables then
    if not wezterm.gui then return end
    tables = wezterm.gui.default_key_tables()
  end
  tables.search_mode = tables.search_mode
    or (wezterm.gui and wezterm.gui.default_key_tables().search_mode)
    or {}
  for _, binding in ipairs(with_raw_twins(search_keys)) do
    table.insert(tables.search_mode, binding)
  end
  config.key_tables = tables
end

return M
