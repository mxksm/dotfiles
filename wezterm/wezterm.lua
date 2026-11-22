local wezterm = require 'wezterm'
local config = wezterm.config_builder()
config.set_environment_variables = {
  WEZTERM_THEME_REQUEST = wezterm.config_dir .. '/.theme-request.json',
}

-- Keep macOS UI tweak loaders (Ammonia/AppleSharpener) out of terminal
-- processes. Clear the inherited loader for the env launcher, then remove the
-- variable entirely before starting zsh. An empty value must not leak to `open`:
-- GUI launch-time injection can turn it into an empty library path and abort.
if wezterm.target_triple:find('apple-darwin', 1, true) then
  config.set_environment_variables.DYLD_INSERT_LIBRARIES = ''
  config.default_prog = { '/usr/bin/env', '-u', 'DYLD_INSERT_LIBRARIES', '/bin/zsh', '-l' }
  -- Zsh's partial-line marker can be stranded by the first window resize.
  -- An empty marker retains partial-line preservation without a stray %.
  config.set_environment_variables.PROMPT_EOL_MARK = ''
end

local themes = require 'themes'
local theme_state = require 'theme_state'
local keys = require 'keys'
local ui = require 'ui'

-- The Neovim instance handling a SyncTeX inverse search emits this event.
wezterm.on('user-var-changed', function(window, pane, name, value)
  if name == 'NVIM_THEME' then
    require('nvim_theme').apply(window, pane, value)
    return
  end
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
