local themes = {
  flexoki = {
    background = '#100F0F',
    foreground = '#CECDC3',
  },
  
  monokai = {
    background = '#100c0c',
    foreground = '#ffffff',
  },

  slate = {
    background = '#282C34',
    foreground = '#F8F9FA',
  },

  tokyo_dracula = {
    background = '#1a1b26',
    foreground = '#ffffff',
  },

  gray_5 = {
    background = '#201912',
    foreground = '#E8DFD2',
    cursor_bg = '#E8DFD2',
    cursor_fg = '#201912',
    cursor_border = '#E8DFD2',
    selection_bg = '#3A2E25',
    selection_fg = '#FFFFFF',
    ansi = {
      '#201912',
      '#E37A73',
      '#A7BF6A',
      '#E0BE68',
      '#80B8C4',
      '#BFA0E0',
      '#80B8C4',
      '#E8DFD2',
    },
    brights = {
      '#3A2E25',
      '#E37A73',
      '#A7BF6A',
      '#E0BE68',
      '#80B8C4',
      '#BFA0E0',
      '#80B8C4',
      '#FFF6E8',
    },
  },

  gruvbox_light = {
    background = '#fbf1c7',
    foreground = '#000000',
  },

  catppuccin_latte = {
    background = '#eff1f5',
    foreground = '#000000',
  },

  white = {
    background = '#ffffff',
    foreground = '#000000',
  }
}

-- Build tab styling once for every preset, including shell-only windows.
for name, colors in pairs(themes) do
  themes[name] = require('tab_colors').with_tabs(colors)
end
return themes
