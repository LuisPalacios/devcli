-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices.

-- For example, changing the initial geometry for new windows:
config.initial_cols = 120
config.initial_rows = 28

-- or, changing the font size and color scheme.
config.font_size = 10
config.color_scheme = 'AdventureTime'

-- Configure a key binding to start a multi pane session
config.keys = {
  {
    key = 'n',
    mods = 'CTRL|SUPER',
    action = wezterm.action_callback(function(window, pane)
      -- The new panes automatically inherit the CWD of the current pane

      -- 1. Split right (35% of screen for Sonnet)
      local right_pane = pane:split { direction = 'Right', size = 0.35 }
      right_pane:send_text('claude --model sonnet\n')

      -- 2. Split left pane down (Shell)
      local bottom_left_pane = pane:split { direction = 'Bottom', size = 0.3 }

      -- 3. Split right pane down (Haiku)
      local bottom_right_pane = right_pane:split { direction = 'Bottom', size = 0.5 }
      bottom_right_pane:send_text('claude --model haiku\n')

      -- Send Opus command to the original top-left pane
      pane:send_text('claude --model opus\n')
    end),
  },
}

return config
