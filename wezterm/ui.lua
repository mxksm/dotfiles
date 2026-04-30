-- ui.lua
local wezterm = require 'wezterm'

-- We return a function that applies settings to the main config object
return function(config)
  config.font_size = 15.0
  config.window_decorations = "RESIZE | MACOS_FORCE_SQUARE_CORNERS"
  config.tab_bar_at_bottom = true
  config.show_new_tab_button_in_tab_bar = false
  config.hide_tab_bar_if_only_one_tab = true

  config.window_padding = {
    top = 10,
    bottom = 10,
  }

  -- Remove default window closing confirmation
  config.window_close_confirmation = 'NeverPrompt'

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
end
