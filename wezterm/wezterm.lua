local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Keep macOS UI tweak loaders (Ammonia/AppleSharpener) out of terminal
-- processes. This must be set before the shell starts, not in .zshrc.
if wezterm.target_triple:find('apple-darwin', 1, true) then
  config.set_environment_variables = {
    DYLD_INSERT_LIBRARIES = '',
  }
end

local themes = require 'themes'
local theme_state = require 'theme_state'
local keys = require 'keys'
local ui = require 'ui'

-- The Neovim instance handling a SyncTeX inverse search emits this event.
wezterm.on('user-var-changed', function(window, pane, name)
  if name == 'SIOYEK_SOURCE_JUMP' then
    local tab = pane:tab()
    tab:activate()
    tab:set_zoomed(false)
    pane:activate()
    window:focus()
  end
end)

config.colors = theme_state.read(themes, 'monokai')
config.keys = keys

ui.apply(config)

return config
