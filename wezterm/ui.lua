-- ui.lua
local wezterm = require 'wezterm'

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
  local tab_bar_background = theme_colors.tab_bar.background
  theme_colors.tab_bar.inactive_tab_edge = tab_bar_background
  for _, state in ipairs {
    'active_tab',
    'inactive_tab',
    'inactive_tab_hover',
    'new_tab',
    'new_tab_hover',
  } do
    if theme_colors.tab_bar[state] then
      theme_colors.tab_bar[state].underline = 'None'
    end
  end

  return {
    background = {
      {
        source = { Color = theme_colors.background },
        width = '100%',
        height = '100%',
        repeat_x = 'NoRepeat',
        repeat_y = 'NoRepeat',
      },
      {
        source = { Color = '#ffffff' },
        width = '100%',
        height = 2,
        opacity = 0.75,
        repeat_x = 'NoRepeat',
        repeat_y = 'NoRepeat',
        vertical_align = 'Top',
        vertical_offset = '1cell',
        attachment = 'Fixed',
      },
    },
  }
end

local function apply(config)
  config.font_size = 15.0
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

  -- Remove default window closing confirmation
  config.window_close_confirmation = 'NeverPrompt'

  config.use_fancy_tab_bar = false
  config.tab_max_width = 999

  local appearance = tab_appearance(config.colors)
  config.background = appearance.background

  wezterm.on('format-tab-title', function(tab)
    local elements = {}

    if tab.is_active then
      table.insert(elements, { Attribute = { Intensity = 'Bold' } })
    else
      table.insert(elements, { Attribute = { Intensity = 'Normal' } })
    end

    local title = string.format(' %d: %s ', tab.tab_index + 1, formatted_tab_title(tab))
    table.insert(elements, { Text = title })

    return elements
  end)

  -- Center the full group in terminal columns, which is independent of DPI.
  wezterm.on('update-status', function(window, pane)
    local tabs = window:mux_window():tabs()
    local total_tabs_width = 0

    for index, tab in ipairs(tabs) do
      local label = string.format(' %d: %s ', index, mux_tab_title(tab))
      total_tabs_width = total_tabs_width + wezterm.column_width(label)
    end

    local columns = pane:get_dimensions().cols
    local remaining = math.max(columns - total_tabs_width, 0)
    local left_padding = math.floor(remaining / 2)
    window:set_left_status(string.rep(' ', left_padding))
    window:set_right_status('')
  end)
end

return {
  apply = apply,
  tab_appearance = tab_appearance,
}
