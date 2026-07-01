-- wezterm.lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

local themes = require 'themes'
local theme_state = require 'theme_state'
local keys = require 'keys'
local setup_ui = require 'ui'

config.colors = theme_state.read(themes, 'monokai')
config.keys = keys

setup_ui(config)

return config
