-- Run: nvim --headless -u NONE -i NONE -l wezterm/tests/theme_sync.lua
local root = vim.fn.getcwd()
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, 'p')
vim.opt.rtp:prepend(root .. '/nvim')
for _, path in ipairs(vim.fn.glob(vim.fn.stdpath('data') .. '/lazy/*', false, true)) do
  vim.opt.rtp:append(path)
end
vim.env.XDG_STATE_HOME = temp .. '/state'
vim.env.WEZTERM_THEME_REQUEST = temp .. '/.theme-request.json'
vim.g.base46_cache = temp .. '/base46/'
package.path = root .. '/wezterm/?.lua;' .. root .. '/nvim/lua/?.lua;' .. package.path
local editor_themes = require 'configs.sioyek_themes'
editor_themes.register()
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
  local previous = messages
  vim.api.nvim_exec_autocmds(event or 'User', event and {} or { pattern = 'NvThemeReload' })
  assert(vim.wait(500, function() return messages > previous end), 'theme event published')
  assert(overrides.colors.background == bg and overrides.colors.foreground == fg)
  assert(overrides.colors.tab_bar.background == bg and overrides.window_frame.active_titlebar_bg == bg)
  local tabs = overrides.colors.tab_bar
  assert(tabs.active_tab.bg_color ~= tabs.inactive_tab.bg_color, 'active tab has a distinct background')
  assert(tabs.active_tab.fg_color == fg and tabs.inactive_tab.fg_color ~= fg, 'inactive labels are muted')
  assert(tabs.inactive_tab.bg_color == bg, 'rest of tab bar matches terminal')
  assert(tabs.inactive_tab_hover.bg_color ~= tabs.active_tab.bg_color, 'hover remains distinct from active tab')
  assert(overrides.font_size == 19 and next(overrides.background) == nil, 'zoom preserved and opaque layer removed')
  assert(state.read(presets, 'monokai').background == bg, 'palette survives reload/restart')
end
send('#282c34', '#eeeeee')
send('#eff1f5', '#4c4f69') -- light preview
send('#282c34', '#eeeeee') -- Escape rollback
send('#123456', '#fedcba', 'ColorScheme') -- arbitrary, non-preset theme
send('#654321', '#abcdef', 'SafeState') -- themes that do not emit ColorScheme/NvThemeReload
local get_hl = vim.api.nvim_get_hl
vim.api.nvim_get_hl = function(ns, opts)
  if opts.name == 'Normal' and opts.link == false then return { bg = 0x222222 } end
  return get_hl(ns, opts)
end
assert(editor.palette().background == '#654321', 'floating picker winhl cannot replace global theme palette')
vim.api.nvim_get_hl = get_hl
vim.api.nvim_set_hl(0, 'SharedThemeNormal', { bg = '#654321', fg = '#abcdef' })
vim.api.nvim_set_hl(0, 'Normal', { link = 'SharedThemeNormal' })
assert(editor.palette().background == '#654321', 'global Normal links are resolved')
local unchanged = messages
vim.api.nvim_exec_autocmds('SafeState', {})
assert(messages == unchanged, 'idle input does not resend unchanged palettes')
vim.api.nvim_exec_autocmds('FocusGained', {})
assert(messages == unchanged + 1, 'focus still restores the active editor palette')
local before = vim.deepcopy(overrides)
theme.apply(window, pane, '{bad json')
theme.apply(window, pane, vim.json.encode { colors = { background = 'bad', foreground = '#ffffff' } })
theme.apply(window, { pane_id = function() return 2 end }, vim.json.encode { colors = { background = '#ffffff', foreground = '#000000' } })
assert(vim.deep_equal(before, overrides), 'malformed and inactive-pane events ignored')
-- Exercise the actual Option+number callbacks, followed by the focus events
-- that used to immediately undo them. Keep unrelated zoom overrides intact.
mock.action_callback = function(callback) return callback end
mock.action = setmetatable({}, { __index = function(_, name)
  return function(value) return { name = name, value = value } end
end })
local reloads = 0
mock.reload_configuration = function() reloads = reloads + 1 end
local favorites = { ['1'] = 'flexoki', ['2'] = 'monokai', ['3'] = 'slate',
  ['4'] = 'tokyo_dracula', ['5'] = 'gray_5', ['8'] = 'gruvbox_light',
  ['9'] = 'catppuccin_latte', ['0'] = 'white' }
local names = { ['1'] = 'Flexoki Dark', ['2'] = 'Monokai Midnight', ['3'] = 'Slate',
  ['4'] = 'Tokyo Dracula', ['5'] = 'Cocoa', ['8'] = 'Gruvbox Light',
  ['9'] = 'Catppuccin Latte', ['0'] = 'Paper White' }
local tested = 0
for _, binding in ipairs(require 'keys') do
  local name = binding.mods == 'ALT' and favorites[binding.key]
  if name then
    binding.action(window, pane)
    local expected = presets[name].background:lower()
    local applied = vim.wait(2000, function() return editor_themes.selected() == names[binding.key]
      and overrides.colors.background == expected end)
    assert(applied, 'watcher applies ' .. name .. ' to both apps; got '
      .. editor_themes.selected() .. ' / ' .. overrides.colors.background)
    assert(require('nvconfig').base46.theme == names[binding.key], 'actual editor theme changed')
    assert(vim.deep_equal(overrides.colors.ansi, editor.palette().ansi), 'full editor ANSI palette synced')
    vim.api.nvim_exec_autocmds('FocusGained', {})
    vim.api.nvim_exec_autocmds('SafeState', {})
    assert(overrides.colors.background == expected, 'focus preserves ' .. name)
    assert(state.read(presets, 'monokai').background == expected, 'preset survives config reload')
    assert(overrides.font_size == 19, 'shortcut preserves zoom')
    tested = tested + 1
  end
end
assert(tested == 8 and reloads == 8, 'all eight favorites exercised')
local selected = overrides.colors.background
package.loaded['configs.wezterm_theme'] = nil
editor = require 'configs.wezterm_theme'
editor.setup()
editor.publish(true)
assert(overrides.colors.background == selected, 'editor restart preserves shared choice')
send('#102030', '#eeeeee', 'SafeState')
send('#eff1f5', '#4c4f69') -- preview after manual preset
send('#102030', '#eeeeee') -- preview rollback still works
editor_themes.save('Graphite')
editor.setup()
assert(editor_themes.selected() == 'Graphite' and editor.palette().background == '#102030',
  'consumed shortcut cannot undo a later editor choice on restart')
-- A shortcut selected without a running editor is consumed at next startup.
vim.api.nvim_exec_autocmds('VimLeavePre', {})
assert(state.request_editor_theme('monokai'))
editor.setup()
assert(editor_themes.selected() == 'Monokai Midnight' and overrides.colors.background == '#100c0c',
  'shell shortcut applies on next editor startup')
local prior = messages
assert(state.request_editor_theme('monokai'))
assert(vim.wait(2000, function() return messages > prior end), 'reselecting same favorite still syncs')
local valid_request = vim.fn.readfile(vim.env.WEZTERM_THEME_REQUEST)
vim.fn.writefile({ '{bad json' }, vim.env.WEZTERM_THEME_REQUEST)
vim.api.nvim_exec_autocmds('FocusGained', {})
assert(editor_themes.selected() == 'Monokai Midnight', 'invalid request ignored')
vim.fn.writefile({ vim.json.encode { id = 'unknown', preset = 'not-a-theme' } }, vim.env.WEZTERM_THEME_REQUEST)
vim.api.nvim_exec_autocmds('FocusGained', {})
assert(editor_themes.selected() == 'Monokai Midnight', 'unknown favorite ignored')
vim.fn.writefile(valid_request, vim.env.WEZTERM_THEME_REQUEST)
vim.api.nvim_set_hl(0, 'Normal', { fg = '#ffffff' })
assert(editor.palette() == nil, 'explicit transparency is respected')
local handlers = {}
mock.on = function(name, callback) handlers[name] = callback end
local ui = require 'ui'
ui.apply { colors = theme.colors { background = '#282c34', foreground = '#eeeeee' } }
overrides.colors = theme.colors { background = '#282c34', foreground = '#eeeeee' }
overrides.colors.tab_bar.active_tab = { bg_color = '#282c34', fg_color = '#eeeeee' }
overrides.colors.tab_bar.inactive_tab = { bg_color = '#282c34', fg_color = '#eeeeee' }
window.effective_config = function() return { colors = overrides.colors } end
local updates = 0
window.set_config_overrides = function(_, value) overrides = value; updates = updates + 1 end
handlers['window-config-reloaded'](window)
assert(updates == 1 and overrides.colors.tab_bar.active_tab.bg_color ~= overrides.colors.tab_bar.inactive_tab.bg_color,
  'reload repairs existing identical tab overrides')
handlers['window-config-reloaded'](window)
assert(updates == 1, 'repair does not cause a reload loop')
vim.api.nvim_exec_autocmds('VimLeavePre', {})
vim.fn.delete(temp, 'rf')
print('PASS: eight shared shortcuts, real editor themes and file watcher, OSC sync, restart persistence, shell requests, preview rollback and validation')
