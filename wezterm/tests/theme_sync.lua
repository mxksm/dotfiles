-- Run: nvim --headless -u NONE -i NONE -l wezterm/tests/theme_sync.lua
local root = vim.fn.getcwd()
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, 'p')
package.path = root .. '/wezterm/?.lua;' .. root .. '/nvim/lua/?.lua;' .. package.path
local mock = { config_dir = temp, json_parse = vim.json.decode, json_encode = vim.json.encode,
  font = function(name) return name end, log_error = function(message) error(message) end }
package.loaded.wezterm = mock
local theme = require 'nvim_theme'
local state = require 'theme_state'
local presets = require 'themes'
local pane = { pane_id = function() return 1 end }
local overrides = { font_size = 19 }
local window = {
  active_pane = function() return pane end,
  get_config_overrides = function() return overrides end,
  set_config_overrides = function(_, value) overrides = value end,
}
local editor = require 'configs.wezterm_theme'
vim.env.WEZTERM_PANE = '1'
vim.api.nvim_list_uis = function() return { {} } end
local messages = 0
vim.api.nvim_ui_send = function(sequence)
  local data = sequence:match('SetUserVar=NVIM_THEME=(.-)\007')
  assert(data, 'valid OSC user variable')
  theme.apply(window, pane, vim.base64.decode(data))
  messages = messages + 1
end
editor.setup()
local function send(bg, fg, event)
  vim.api.nvim_set_hl(0, 'Normal', { bg = bg, fg = fg })
  vim.api.nvim_exec_autocmds(event or 'User', event and {} or { pattern = 'NvThemeReload' })
  local previous = messages
  assert(vim.wait(500, function() return messages > previous end), 'theme event published')
  assert(overrides.colors.background == bg and overrides.colors.foreground == fg)
  assert(overrides.colors.tab_bar.background == bg and overrides.window_frame.active_titlebar_bg == bg)
  assert(overrides.font_size == 19 and next(overrides.background) == nil, 'zoom preserved and opaque layer removed')
  assert(state.read(presets, 'monokai').background == bg, 'palette survives reload/restart')
end
send('#282c34', '#eeeeee')
send('#eff1f5', '#4c4f69') -- light preview
send('#282c34', '#eeeeee') -- Escape rollback
send('#123456', '#fedcba', 'ColorScheme') -- arbitrary, non-preset theme
local before = vim.deepcopy(overrides)
theme.apply(window, pane, '{bad json')
theme.apply(window, pane, vim.json.encode { colors = { background = 'bad', foreground = '#ffffff' } })
theme.apply(window, { pane_id = function() return 2 end }, vim.json.encode { colors = { background = '#ffffff', foreground = '#000000' } })
assert(vim.deep_equal(before, overrides), 'malformed and inactive-pane events ignored')
assert(state.write('catppuccin_latte'))
assert(state.read(presets, 'monokai').background == presets.catppuccin_latte.background, 'favorite presets still work')
vim.api.nvim_set_hl(0, 'Normal', { fg = '#ffffff' })
assert(editor.palette() == nil, 'explicit transparency is respected')
vim.fn.delete(temp, 'rf')
print('PASS: real Neovim events and OSC payloads, arbitrary/light/dark palettes, preview rollback, persistence, preset fallback, validation, unrelated overrides')
