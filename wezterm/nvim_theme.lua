local wezterm = require 'wezterm'
local M = {}

local function color(value)
  return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
end

-- Mix the theme's own colors so both light and dark palettes remain coherent.
local function blend(bg, fg, amount)
  local channels = {}
  for i = 2, 6, 2 do
    local a, b = tonumber(bg:sub(i, i + 1), 16), tonumber(fg:sub(i, i + 1), 16)
    channels[#channels + 1] = math.floor(a + (b - a) * amount + 0.5)
  end
  return string.format('#%02x%02x%02x', channels[1], channels[2], channels[3])
end

-- Accept only palette data, never arbitrary configuration from a terminal pane.
function M.colors(value)
  if type(value) ~= 'table' or not color(value.background) or not color(value.foreground) then return nil end
  local bg, fg = value.background, value.foreground
  local colors = { background = bg, foreground = fg, cursor_bg = fg, cursor_fg = bg,
    selection_bg = fg, selection_fg = bg, tab_bar = { background = bg, inactive_tab_edge = bg } }
  for _, name in ipairs { 'ansi', 'brights' } do
    local list = value[name]
    if type(list) == 'table' and #list == 8 then
      local valid = true
      for _, entry in ipairs(list) do if not color(entry) then valid = false end end
      if valid then colors[name] = list end
    end
  end
  colors.tab_bar.active_tab = { bg_color = blend(bg, fg, 0.14), fg_color = fg }
  for _, state in ipairs { 'inactive_tab', 'new_tab' } do
    colors.tab_bar[state] = { bg_color = bg, fg_color = blend(bg, fg, 0.65) }
  end
  for _, state in ipairs { 'inactive_tab_hover', 'new_tab_hover' } do
    colors.tab_bar[state] = { bg_color = blend(bg, fg, 0.07), fg_color = fg }
  end
  return colors
end

function M.apply(window, pane, value)
  local active = window:active_pane()
  if not active or active:pane_id() ~= pane:pane_id() then return end
  local ok, payload = pcall(wezterm.json_parse, value or '')
  local colors = ok and type(payload) == 'table' and M.colors(payload.colors)
  if not colors then return end
  -- An explicit terminal preset wins over startup/focus announcements. A real
  -- editor palette change (including picker previews) resumes synchronization.
  if payload.changed == false and require('theme_state').preset_selected() then return end
  local overrides = window:get_config_overrides() or {}
  local appearance = require('ui').tab_appearance(colors)
  overrides.colors = colors
  overrides.background = {}
  overrides.window_frame = appearance.window_frame
  window:set_config_overrides(overrides)
  -- Keep the same palette in the shell after Neovim exits and in new windows.
  require('theme_state').write_colors(colors)
end

return M
