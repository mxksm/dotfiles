-- theme_state.lua
local M = {}

local function state_path()
  return os.getenv('HOME') .. '/.config/wezterm/last_theme'
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
  local file = io.open(state_path(), 'w')

  if not file then
    return
  end

  file:write(theme_name .. '\n')
  file:close()
end

return M
