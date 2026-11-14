local wezterm = require 'wezterm'
local M = {}

local function color(value)
  return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
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
  for _, state in ipairs { 'active_tab', 'inactive_tab', 'inactive_tab_hover', 'new_tab', 'new_tab_hover' } do
    colors.tab_bar[state] = { bg_color = bg, fg_color = fg }
  end
  return colors
end

function M.apply(window, pane, value)
  local active = window:active_pane()
  if not active or active:pane_id() ~= pane:pane_id() then return end
  local ok, payload = pcall(wezterm.json_parse, value or '')
  local colors = ok and type(payload) == 'table' and M.colors(payload.colors)
  if not colors then return end
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
