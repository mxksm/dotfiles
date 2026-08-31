-- ui.lua
local wezterm = require 'wezterm'

-- Match the compact custom tab strip in Firefox.
local TAB_FONT_SIZE = 11.0
local TAB_LAYOUT_FONT_SIZE = 5.0
local TAB_FONT_CELL_WIDTH = 6.625
local TAB_HORIZONTAL_PADDING = 16

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

-- We return a function that applies settings to the main config object
return function(config)
  config.font_size = 15.0
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

  -- The native-style bar is the only mode with an independently-sized tab font.
  config.use_fancy_tab_bar = true

  local tab_bar_background = config.colors.tab_bar.background
  config.colors.tab_bar.inactive_tab_edge = tab_bar_background
  local background_color = wezterm.color.parse(tab_bar_background)
  local _, _, lightness = background_color:hsla()
  local divider_color

  if lightness > 0.5 then
    divider_color = background_color:darken_fixed(0.04)
  else
    divider_color = background_color:lighten_fixed(0.04)
  end

  config.window_frame = {
    -- Firefox resolves its ui-monospace stack to Menlo on this Mac.
    -- WezTerm bases the bar height on the unscaled font metrics. Rendering
    -- Menlo larger inside the smallest unclipped metrics keeps the glyphs at
    -- Firefox's 11px while making the native bar as compact as WezTerm allows.
    font = wezterm.font_with_fallback {
      {
        family = 'JetBrains Mono',
        weight = 'Regular',
        scale = TAB_FONT_SIZE / TAB_LAYOUT_FONT_SIZE,
      },
    },
    font_size = TAB_LAYOUT_FONT_SIZE,
    active_titlebar_bg = tab_bar_background,
    inactive_titlebar_bg = tab_bar_background,
  }

  -- On macOS, WezTerm does not paint the fancy titlebar's advertised bottom
  -- border at the pane boundary. A one-pixel layer at the top of the terminal
  -- viewport produces the same full-width separator Firefox paints there.
  config.background = {
    {
      source = { Color = config.colors.background },
      width = '100%',
      height = '100%',
      repeat_x = 'NoRepeat',
      repeat_y = 'NoRepeat',
    },
    {
      source = { Color = divider_color },
      width = '100%',
      height = '1px',
      repeat_x = 'NoRepeat',
      repeat_y = 'NoRepeat',
      vertical_align = 'Top',
      vertical_offset = 45,
    },
  }

  wezterm.on('format-tab-title', function(tab)
    local elements = {}

    if tab.is_active then
      table.insert(elements, { Attribute = { Intensity = 'Bold' } })
    else
      table.insert(elements, { Attribute = { Intensity = 'Normal' } })
    end

    table.insert(elements, {
      Text = string.format(' %d: %s ', tab.tab_index + 1, formatted_tab_title(tab)),
    })

    return elements
  end)

  -- Add an event listener that recalculates the layout every time the status updates
  wezterm.on('update-status', function(window, pane)
    local tabs = window:mux_window():tabs()
    local total_tabs_width = #tabs * TAB_HORIZONTAL_PADDING

    -- Measure the labels using the same Menlo metrics as the tab bar.
    for index, tab in ipairs(tabs) do
      local label = string.format('%d: %s', index, mux_tab_title(tab))
      total_tabs_width = total_tabs_width
        + wezterm.column_width(label) * TAB_FONT_CELL_WIDTH
    end

    local dimensions = window:get_dimensions()
    if not dimensions.dpi or dimensions.dpi <= 0 then
      return
    end

    local scale = dimensions.dpi / 72
    local screen_width = dimensions.pixel_width / scale

    local left_padding = math.floor(
      (screen_width - total_tabs_width) / 2 / TAB_FONT_CELL_WIDTH
    )
    if left_padding < 0 then
      left_padding = 0
    end

    -- Push the group, rather than each individual tab, into the center.
    window:set_left_status(string.rep(' ', left_padding))
  end)
end
