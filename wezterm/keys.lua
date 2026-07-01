-- keys.lua
local wezterm = require 'wezterm'
local themes = require 'themes'
local theme_state = require 'theme_state'

-- Helper function to hot-swap the theme
local function change_theme(theme_name)
  return wezterm.action_callback(function(window, pane)
    local theme_colors = themes[theme_name]

    if not theme_colors then
      return
    end

    theme_state.write(theme_name)

    -- Fetch the current overrides so we don't wipe out other runtime changes
    local overrides = window:get_config_overrides() or {}
    overrides.colors = theme_colors
    window:set_config_overrides(overrides)
  end)
end

-- Keep the window alive when closing its final pane/tab.
local function close_pane_or_refresh_window(window, pane)
  local mux_window = window:mux_window()
  local tabs = mux_window:tabs()
  local panes = pane:tab():panes()

  if #tabs == 1 and #panes == 1 then
    window:perform_action(wezterm.action.SpawnCommandInNewTab {
      cwd = wezterm.home_dir,
    }, pane)
  end

  window:perform_action(wezterm.action.CloseCurrentPane { confirm = true }, pane)
end

-- Close every tab in this window without quitting other WezTerm windows.
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
  -- Clean screen
  {
    key = 'k',
    mods = 'CMD',
    action = wezterm.action.ClearScrollback 'ScrollbackAndViewport',
  },
  -- Disable default full screen shortcut
  {
    key = 'Enter',
    mods = 'ALT',
    action = wezterm.action.DisableDefaultAssignment,
  },
  -- New tab
  {
    key = 't',
    mods = 'CMD',
    action = wezterm.action.SpawnCommandInNewTab {
      cwd = wezterm.home_dir, 
    },
  },
  -- Custom quit message
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
  -- Split horizontally (left/right)
  {
    key = 'd',
    mods = 'CMD',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  -- Split vertically (top/bottom)
  {
    key = 'd',
    mods = 'CMD|SHIFT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  -- Close current pane (acts like closing a tab if there's only one pane)
  {
    key = 'w',
    mods = 'CMD',
    action = wezterm.action_callback(close_pane_or_refresh_window),
  },
  -- Close only this window (not the whole WezTerm application)
  {
    key = 'w',
    mods = 'CMD|SHIFT',
    action = wezterm.action_callback(close_current_window),
  },
  -- Move current tab left/right with Cmd+< and Cmd+>
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
  -- Move between panes
  { key = 'h', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'l', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'k', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'j', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection 'Down' },
  -- Enter Copy Mode
  {
    key = 'x',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ActivateCopyMode,
  },
  -- Quickly search your terminal history
  {
    key = 'f',
    mods = 'CMD',
    action = wezterm.action.Search { CaseInSensitiveString = '' },
  },
  -- Open the Command Palette
  {
    key = 'p',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ActivateCommandPalette,
  },
  -- Theme Switching Shortcuts
  { key = '1', mods = 'ALT', action = change_theme('flexoki') },
  { key = '2', mods = 'ALT', action = change_theme('monokai') },
  { key = '3', mods = 'ALT', action = change_theme('slate') },
  { key = '4', mods = 'ALT', action = change_theme('tokyo_dracula') },
  { key = '5', mods = 'ALT', action = change_theme('gray_5') },
  { key = '8', mods = 'ALT', action = change_theme('gruvbox_light') },
  { key = '9', mods = 'ALT', action = change_theme('catppuccin_latte') },
  { key = '0', mods = 'ALT', action = change_theme('white') },
}
