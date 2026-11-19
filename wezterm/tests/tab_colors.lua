-- Run from dotfiles: nvim --headless -u NONE -i NONE -l wezterm/tests/tab_colors.lua
local root, temp = vim.fn.getcwd(), vim.fn.tempname()
vim.fn.mkdir(temp, 'p')
package.path = root .. '/wezterm/?.lua;' .. root .. '/nvim/lua/?.lua;' .. package.path
local handlers = {}
package.loaded.wezterm = {
  config_dir = temp, json_parse = vim.json.decode, json_encode = vim.json.encode,
  font = function(name) return name end, log_error = error,
  on = function(name, callback) handlers[name] = callback end,
}
local ui, sync, state = require 'ui', require 'nvim_theme', require 'theme_state'
local presets = require 'themes'
local names = { flexoki = 'Flexoki Dark', monokai = 'Monokai Midnight', slate = 'Slate',
  tokyo_dracula = 'Tokyo Dracula', gray_5 = 'Cocoa', gruvbox_light = 'Gruvbox Light',
  catppuccin_latte = 'Catppuccin Latte', white = 'Paper White' }
local catalog = require 'configs.sioyek_palettes'
local by_name = {}
for _, entry in ipairs(catalog) do by_name[entry.name] = entry.colors end

local function check_render(colors)
  local config = { colors = colors }
  ui.apply(config)
  local tabs = config.colors.tab_bar
  local bg = colors.background:lower()
  assert(tabs.background == bg and tabs.inactive_tab.bg_color == bg, 'neutral bar and inactive tabs')
  assert(tabs.active_tab.bg_color ~= bg, 'active rectangle is always visible')
  assert(tabs.inactive_tab_hover.bg_color ~= bg
    and tabs.inactive_tab_hover.bg_color ~= tabs.active_tab.bg_color, 'hover distinct from active and idle')
  assert(tabs.inactive_tab_edge == bg and tabs.inactive_tab_edge_hover == bg, 'no stray hover border')
  for _, active in ipairs { true, false } do
    for _, hover in ipairs { true, false } do
      local tab = { is_active = active, tab_index = 1, tab_title = 'notes 中文', active_pane = {} }
      local parts = handlers['format-tab-title'](tab, {}, {}, config, hover)
      local expected = active and tabs.active_tab or (hover and tabs.inactive_tab_hover or tabs.inactive_tab)
      assert(parts[2].Background.Color == bg and parts[7].Background.Color == bg, 'neutral rectangular edges')
      assert(parts[4].Background.Color == expected.bg_color and parts[5].Foreground.Color == expected.fg_color,
        'formatter uses the correct active/hover/idle colors')
      assert(parts[1].Attribute.Intensity == (active and 'Bold' or 'Normal'), 'bold cannot leak to inactive tabs')
      assert(parts[6].Text == ' 2: notes 中文 ', 'title and tab number preserved')
    end
  end
  return tabs
end

for preset, name in pairs(names) do
  local colors = presets[preset]
  local original = vim.deepcopy(colors)
  local tabs = check_render(colors)
  assert(vim.deep_equal(original, colors), 'appearance must not mutate shared presets')
  local source = by_name[name]
  local editor = sync.colors { background = source.custom_background_color, foreground = source.custom_text_color }
  assert(vim.deep_equal(tabs, check_render(editor)), name .. ': shell and editor have identical tabs')
  assert(state.write(preset))
  assert(vim.deep_equal(tabs, check_render(state.read(presets, 'monokai'))), 'saved preset startup')
  assert(state.write_colors(editor))
  assert(vim.deep_equal(tabs, check_render(state.read(presets, 'monokai'))), 'saved editor startup')
end
for _, entry in ipairs(catalog) do
  check_render(sync.colors { background = entry.colors.custom_background_color,
    foreground = entry.colors.custom_text_color })
end
os.remove(temp .. '/.theme-state.json')
vim.fn.writefile({ 'slate' }, temp .. '/.last_theme')
assert(vim.deep_equal(check_render(state.read(presets, 'monokai')), check_render(presets.slate)), 'legacy startup')
os.remove(temp .. '/.last_theme')
assert(vim.deep_equal(check_render(state.read(presets, 'monokai')), check_render(presets.monokai)), 'fresh startup')

local base = { colors = vim.deepcopy(presets.gray_5) }
ui.apply(base)
local cases = {
  -- Original bug: different text colors hid the missing rectangle from repair.
  { active_tab = { bg_color = base.colors.background, fg_color = '#ffffff' },
    inactive_tab = { bg_color = base.colors.background, fg_color = '#888888' } },
  { active_tab = { bg_color = '#ffffff', fg_color = '#000000' } }, -- stale light theme
  {}, -- missing hover and idle states
}
for _, broken in ipairs(cases) do
  local overrides = { colors = vim.deepcopy(base.colors), font_size = 21,
    window_frame = { font_size = 18, border_left_width = '2px' }, background = { { Color = '#ff0000' } } }
  overrides.colors.tab_bar = broken
  local preserved = vim.deepcopy(overrides.colors)
  local updates = 0
  local window = {
    get_config_overrides = function() return overrides end,
    effective_config = function() return vim.tbl_deep_extend('force', vim.deepcopy(base), overrides) end,
    set_config_overrides = function(_, value) overrides = value; updates = updates + 1 end,
  }
  -- Add default fields like the real effective_config output does.
  base.colors.tab_bar.extra_default = 'keep comparisons tolerant of defaults'
  handlers['window-config-reloaded'](window)
  assert(updates == 1 and overrides.font_size == 21, 'repair preserves terminal zoom')
  assert(overrides.window_frame.font_size == 12 and overrides.window_frame.border_left_width == '2px',
    'repair fixes tab font and preserves unrelated frame options')
  assert(next(overrides.background) == nil, 'stale background layer removed')
  for key, value in pairs(preserved) do
    if key ~= 'tab_bar' then assert(vim.deep_equal(overrides.colors[key], value), 'preserves terminal color ' .. key) end
  end
  handlers['window-config-reloaded'](window)
  assert(updates == 1, 'no config reload loop')
end
vim.fn.delete(temp, 'rf')
print('PASS: 8 presets and 26 themes, identical shell/editor tabs, startup persistence, active/hover rendering, stale overrides and reload stability')
