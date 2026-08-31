local wezterm = require 'wezterm'
local themes = require 'themes'
local theme_state = require 'theme_state'
local ui = require 'ui'

local function change_theme(theme_name)
  return wezterm.action_callback(function(window, pane)
    local theme_colors = themes[theme_name]

    if not theme_colors then
      return
    end

    if not theme_state.write(theme_name) then
      return
    end

    -- Preserve unrelated runtime overrides.
    local overrides = window:get_config_overrides() or {}
    local appearance = ui.tab_appearance(theme_colors)
    overrides.colors = theme_colors
    overrides.background = appearance.background
    window:set_config_overrides(overrides)
    wezterm.reload_configuration()
  end)
end

local function close_pane_or_refresh_window(window, pane)
  local mux_window = window:mux_window()
  local tabs = mux_window:tabs()
  local active_tab = mux_window:active_tab()
  local panes = active_tab:panes()

  if #tabs == 1 and #panes == 1 then
    window:perform_action(wezterm.action.Confirmation {
      message = '🛑 Close this tab?',
      action = wezterm.action_callback(function(confirmed_window, confirmed_pane)
        confirmed_window:perform_action(wezterm.action.SpawnCommandInNewTab {
          cwd = wezterm.home_dir,
        }, confirmed_pane)
        confirmed_window:perform_action(wezterm.action.ActivateTabRelative(-1), confirmed_pane)
        confirmed_window:perform_action(wezterm.action.CloseCurrentTab { confirm = false }, confirmed_pane)
      end),
    }, pane)
    return
  end

  window:perform_action(wezterm.action.CloseCurrentPane { confirm = true }, pane)
end

local function close_current_window(window, pane)
  window:perform_action(wezterm.action.Confirmation {
    message = '🛑 Close this window?',
    action = wezterm.action_callback(function(confirmed_window, _)
      for _, tab in ipairs(confirmed_window:mux_window():tabs()) do
        local tab_panes = tab:panes()
        if tab_panes[1] then
          confirmed_window:perform_action(
            wezterm.action.CloseCurrentTab { confirm = false },
            tab_panes[1]
          )
        end
      end
    end),
  }, pane)
end

return {
  {
    key = 'k',
    mods = 'CMD',
    action = wezterm.action.ClearScrollback 'ScrollbackAndViewport',
  },
  {
    key = 'Enter',
    mods = 'ALT',
    action = wezterm.action.DisableDefaultAssignment,
  },
  {
    key = 't',
    mods = 'CMD',
    action = wezterm.action.SpawnCommandInNewTab {
      cwd = wezterm.home_dir,
    },
  },
  {
    key = 'q',
    mods = 'CMD',
    action = wezterm.action.Confirmation {
      message = '🛑 Kill?',
      action = wezterm.action_callback(function(window, pane)
        window:perform_action(wezterm.action.QuitApplication, pane)
      end),
    },
  },
  {
    key = 'd',
    mods = 'CMD',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'd',
    mods = 'CMD|SHIFT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'w',
    mods = 'CMD',
    action = wezterm.action_callback(close_pane_or_refresh_window),
  },
  {
    key = 'w',
    mods = 'CMD|SHIFT',
    action = wezterm.action_callback(close_current_window),
  },
  {
    key = ',',
    mods = 'CMD|SHIFT',
    action = wezterm.action.MoveTabRelative(-1),
  },
  {
    key = '.',
    mods = 'CMD|SHIFT',
    action = wezterm.action.MoveTabRelative(1),
  },
  { key = 'h', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'l', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'k', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'j', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection 'Down' },
  {
    key = 'x',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ActivateCopyMode,
  },
  {
    key = 'f',
    mods = 'CMD',
    action = wezterm.action.Search { CaseInSensitiveString = '' },
  },
  {
    key = 'p',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ActivateCommandPalette,
  },
  { key = '1', mods = 'ALT', action = change_theme('flexoki') },
  { key = '2', mods = 'ALT', action = change_theme('monokai') },
  { key = '3', mods = 'ALT', action = change_theme('slate') },
  { key = '4', mods = 'ALT', action = change_theme('tokyo_dracula') },
  { key = '5', mods = 'ALT', action = change_theme('gray_5') },
  { key = '8', mods = 'ALT', action = change_theme('gruvbox_light') },
  { key = '9', mods = 'ALT', action = change_theme('catppuccin_latte') },
  { key = '0', mods = 'ALT', action = change_theme('white') },
}
