local wezterm = require 'wezterm'
local M = {}

local function state_path()
  return wezterm.config_dir .. '/.last_theme'
end

function M.read(themes, fallback_name)
  local fallback = themes[fallback_name] or themes.monokai
  local file = io.open(state_path(), 'r')

  if not file then
    return fallback
  end

  local theme_name = file:read('*l')
  file:close()

  if theme_name and themes[theme_name] then
    return themes[theme_name]
  end

  return fallback
end

function M.write(theme_name)
  local file, open_error = io.open(state_path(), 'w')

  if not file then
    wezterm.log_error('Unable to save the selected theme: ' .. tostring(open_error))
    return false
  end

  local wrote, write_error = file:write(theme_name .. '\n')

  if not wrote then
    file:close()
    wezterm.log_error('Unable to save the selected theme: ' .. tostring(write_error))
    return false
  end

  local closed, close_error = file:close()

  if not closed then
    wezterm.log_error('Unable to save the selected theme: ' .. tostring(close_error))
    return false
  end

  return true
end

return M
