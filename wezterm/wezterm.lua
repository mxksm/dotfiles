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

config.colors = theme_state.read(themes, 'monokai')
config.keys = keys

ui.apply(config)

return config
