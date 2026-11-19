local wezterm = require 'wezterm'
local M = {}

local function state_path()
  return wezterm.config_dir .. '/.theme-state.json'
end

function M.read(themes, fallback_name)
  local fallback = themes[fallback_name] or themes.monokai
  local file = io.open(state_path(), 'r')
  if file then
    local contents = file:read(65536)
    file:close()
    local ok, state = pcall(wezterm.json_parse, contents or '')
    if ok and type(state) == 'table' then
      if state.preset and themes[state.preset] then return themes[state.preset] end
      local colors = require('nvim_theme').colors(state.colors)
      if colors then return colors end
    end
  end

  -- One-time fallback for the previously selected terminal preset.
  file = io.open(wezterm.config_dir .. '/.last_theme', 'r')
  if not file then return fallback end
  local name = file:read('*l')
  file:close()
  return themes[name] or fallback
end

local function save(state, path)
  path = path or state_path()
  local contents = wezterm.json_encode(state) .. '\n'
  local existing = io.open(path, 'r')
  if existing then
    local unchanged = existing:read('*a') == contents
    existing:close()
    if unchanged then return true end
  end
  local temporary = path .. '.tmp'
  local file, err = io.open(temporary, 'w')
  if not file then wezterm.log_error('Unable to save theme: ' .. tostring(err)); return false end
  local wrote, write_error = file:write(contents)
  local closed, close_error = file:close()
  if not wrote or not closed then
    os.remove(temporary)
    wezterm.log_error('Unable to save theme: ' .. tostring(write_error or close_error))
    return false
  end
  local renamed, rename_error = os.rename(temporary, path)
  if not renamed then
    os.remove(temporary)
    wezterm.log_error('Unable to save theme: ' .. tostring(rename_error))
    return false
  end
  return true
end

function M.write(theme_name)
  return save { preset = theme_name }
end

function M.write_colors(colors)
  return save { colors = colors }
end

function M.request_editor_theme(theme_name)
  -- Separate from palette persistence: an editor's OSC reply must not erase a
  -- request before other running editors have had a chance to read it.
  local path = wezterm.config_dir .. '/.theme-request.json'
  local revision = 0
  local file = io.open(path, 'r')
  if file then
    local contents = file:read(4096)
    file:close()
    local ok, previous = pcall(wezterm.json_parse, contents or '')
    if ok and type(previous) == 'table' and type(previous.revision) == 'number'
      and previous.revision >= 0 and previous.revision < 1000000000 then
      revision = math.floor(previous.revision)
    end
  end
  revision = revision + 1
  return save({ preset = theme_name, revision = revision,
    id = tostring(os.time()) .. ':' .. tostring(revision) }, path)
end

return M
