local wezterm = require 'wezterm'
local tab_colors = require 'tab_colors'

-- Separate from the terminal's font_size and Cmd +/- zoom.
local TAB_FONT_SIZE = 12

local SHELLS = {
  bash = true,
  csh = true,
  dash = true,
  elvish = true,
  fish = true,
  ksh = true,
  nu = true,
  sh = true,
  tcsh = true,
  zsh = true,
}

local function basename(path)
  return path:gsub('[/\\]+$', ''):match('([^/\\]+)$') or path
end

local function cwd_title(cwd)
  if not cwd then
    return nil
  end

  local path = cwd.file_path
  if path == wezterm.home_dir then
    return '~'
  end
  if path == '/' then
    return '/'
  end

  return basename(path)
end

local function pane_title(title, foreground_process_name, cwd)
  local process = basename(foreground_process_name or '')
  if SHELLS[process] then
    return cwd_title(cwd) or title
  end

  return title
end

local function formatted_tab_title(tab)
  if tab.tab_title and #tab.tab_title > 0 then
    return tab.tab_title
  end

  local pane = tab.active_pane
  return pane_title(
    pane.title,
    pane.foreground_process_name,
    pane.current_working_dir
  )
end

local function mux_tab_title(tab)
  local title = tab:get_title()
  if title and #title > 0 then
    return title
  end

  local pane = tab:active_pane()
  return pane_title(
    pane:get_title(),
    pane:get_foreground_process_name(),
    pane:get_current_working_dir()
  )
end

local function tab_appearance(theme_colors)
  local tab_bar_background = theme_colors.background

  return {
    window_frame = {
      font = wezterm.font 'JetBrains Mono',
      font_size = TAB_FONT_SIZE,
      active_titlebar_bg = tab_bar_background,
      inactive_titlebar_bg = tab_bar_background,
      active_titlebar_fg = theme_colors.foreground,
      inactive_titlebar_fg = theme_colors.foreground,
    },

  }
end

local function apply(config)
  config.colors = tab_colors.with_tabs(config.colors)
  config.font_size = 14.0
  config.font = wezterm.font 'JetBrains Mono'
  config.window_decorations = "RESIZE | MACOS_FORCE_SQUARE_CORNERS"
  config.tab_bar_at_bottom = false
  config.show_new_tab_button_in_tab_bar = false
  config.show_close_tab_button_in_tabs = false
  config.hide_tab_bar_if_only_one_tab = false

  config.window_padding = {
    top    = 10,
    bottom = 10,
    left   = 10,
    right  = 10,
  }

  config.window_close_confirmation = 'NeverPrompt'

  config.use_fancy_tab_bar = true
  config.tab_max_width = 999

  local appearance = tab_appearance(config.colors)
  config.background = {} -- Use colors.background, without a fixed opaque layer.
  config.window_frame = appearance.window_frame

  -- Compare just the fields we own: effective_config also includes WezTerm's
  -- defaults. This repairs old overrides without creating a reload loop.
  local function matches(actual, expected)
    if type(expected) ~= 'table' then return actual == expected end
    if type(actual) ~= 'table' then return false end
    for key, value in pairs(expected) do
      if not matches(actual[key], value) then return false end
    end
    return true
  end
  wezterm.on('window-config-reloaded', function(window)
    local overrides = window:get_config_overrides() or {}
    local effective = window:effective_config()
    local expected = tab_colors.for_palette(effective.colors)
    local repair_tabs = not matches(effective.colors.tab_bar, expected)
    local appearance = tab_appearance(effective.colors).window_frame
    local frame = overrides.window_frame or effective.window_frame or {}
    local repair_frame = false
    for key, value in pairs(appearance) do
      if key ~= 'font' and frame[key] ~= value then repair_frame = true end
    end
    if repair_tabs or repair_frame
      or (overrides.background and next(overrides.background)) then
      if repair_tabs then
        overrides.colors = overrides.colors or {}
        overrides.colors.tab_bar = expected
      end
      overrides.window_frame = overrides.window_frame or {}
      for key, value in pairs(appearance) do overrides.window_frame[key] = value end
      overrides.background = {}
      window:set_config_overrides(overrides)
    end
  end)

  wezterm.on('format-tab-title', function(tab, _, _, effective_config, hover)
    local elements = {}

    if tab.is_active then
      table.insert(elements, { Attribute = { Intensity = 'Bold' } })
    else
      table.insert(elements, { Attribute = { Intensity = 'Normal' } })
    end

    local tabs = tab_colors.for_palette(effective_config.colors)
    local state = tab.is_active and tabs.active_tab
      or (hover and tabs.inactive_tab_hover) or tabs.inactive_tab
    -- Fancy tabs derive their rounded outer fill from the first cell.
    -- Keep that cell neutral; color only the rectangular label cells.
    table.insert(elements, { Background = { Color = tabs.background } })
    table.insert(elements, { Text = ' ' })
    table.insert(elements, { Background = { Color = state.bg_color } })
    table.insert(elements, { Foreground = { Color = state.fg_color } })
    local title = string.format(' %d: %s ', tab.tab_index + 1, formatted_tab_title(tab))
    table.insert(elements, { Text = title })
    table.insert(elements, { Background = { Color = tabs.background } })
    table.insert(elements, { Text = ' ' })

    return elements
  end)

  -- Center using the tab font and whole window, never the active pane's terminal
  -- columns. Terminal zoom and splitting panes must not change tab spacing.
  wezterm.on('update-status', function(window)
    local tabs = window:mux_window():tabs()
    local dimensions = window:get_dimensions()
    local scale = dimensions.dpi / 72
    -- JetBrains Mono's glyph advance is 0.6em. Fancy tabs also have half-cell
    -- padding on each side and a one-physical-pixel border on each side.
    local advance = TAB_FONT_SIZE * 0.6 * scale
    local cell_width = math.floor(advance + 0.5)
    local total_tabs_width = 0

    for index, tab in ipairs(tabs) do
      local label = string.format('  %d: %s  ', index, mux_tab_title(tab))
      total_tabs_width = total_tabs_width + wezterm.column_width(label) * advance
        + cell_width + 2
    end

    local remaining = math.max(dimensions.pixel_width - total_tabs_width, 0)
    local left_padding = math.max(0, math.floor((remaining / 2 - cell_width) / advance))
    window:set_left_status(string.rep(' ', left_padding))
    window:set_right_status('')
  end)
end

return {
  apply = apply,
  tab_appearance = tab_appearance,
}
