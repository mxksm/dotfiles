local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.window_decorations = "RESIZE | MACOS_FORCE_SQUARE_CORNERS"
config.tab_bar_at_bottom = true
config.show_new_tab_button_in_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true

config.window_padding = {
  bottom = 0,
}

-- Turn off the fancy tab bar, as this centering trick works best with the retro bar
config.use_fancy_tab_bar = false

-- Add an event listener that recalculates the layout every time the status updates
wezterm.on('update-status', function(window, pane)
  local tabs = window:mux_window():tabs()
  local total_tabs_width = 0

  -- 1. Calculate the approximate width of all tabs combined
  for _, tab in ipairs(tabs) do
    local title = tab:get_title() or ""
    -- The +6 accounts for the tab index, padding spaces, and borders
    total_tabs_width = total_tabs_width + #title + 6 
  end

  -- 2. Get the total width of the terminal window (in columns)
  local screen_width = pane:get_dimensions().cols

  -- 3. Calculate how much empty space is needed on the left to center the tabs
  local left_padding = math.floor((screen_width - total_tabs_width) / 2)
  if left_padding < 0 then
    left_padding = 0 
  end

  -- 4. Inject empty spaces into the left status area to push the tabs to the middle
  window:set_left_status(string.rep(' ', left_padding))
end)

config.keys = {
  {
    key = 'k',
    mods = 'CMD',
    action = wezterm.action.ClearScrollback 'ScrollbackAndViewport',
  },
}

config.font_size = 8.0

-- Custom Color Configuration
config.colors = {
  -- The main background color of the terminal
  background = '#1a1b26', 

  -- Tab bar specific colors
  tab_bar = {
    -- The color of the empty space behind/next to the tabs
    --background = '#0f0f14',
    background = '#1a1b26',

    -- The active (currently selected) tab
    active_tab = {
      bg_color = '#282a36',
      fg_color = '#f8f8f2',
    },

    -- The inactive (unselected) tabs
    inactive_tab = {
      bg_color = '#1a1b26',
      fg_color = '#6272a4',
    },
    
    -- The "new tab" plus button (+) 
    new_tab = {
      bg_color = '#0f0f14',
      fg_color = '#f8f8f2',
    },
  }
}

return config
