-- wezterm.lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

local themes = require 'themes'
local keys = require 'keys'
local setup_ui = require 'ui'

-- Set the default startup theme (Tokyo Night x Dracula Mashup)
config.colors = themes.tokyo_dracula
config.keys = keys

setup_ui(config)

return config
