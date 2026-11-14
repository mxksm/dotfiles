# WezTerm themes

Neovim drives the terminal palette while it is active. Choose any NvChad theme
with `Space th`: its background, foreground, and terminal colors also apply to
WezTerm, including the padding and tabs. Previewing a theme updates the terminal;
Escape restores the previous theme. The shell keeps the chosen palette after
Neovim exits.

The Option+number shortcuts still select the presets in `keys.lua`. They change
the terminal palette, not Neovim’s selected theme. Neovim sends its palette again
when its theme changes or it regains focus.

Neovim must have transparency disabled for its theme to supply a background.
The integration lives in `nvim/lua/configs/wezterm_theme.lua` and
`wezterm/nvim_theme.lua`. Restart existing Neovim sessions after updating it.

The last palette is saved locally in ignored `.theme-state.json`; choosing themes
no longer edits tracked configuration. `.last_theme` is only a fallback for
installations without local state. Sioyek remains independently themed.

Run the integration regression check from the dotfiles root:

```sh
NVIM_LOG_FILE=/tmp/wezterm-theme-test.log nvim --headless -u NONE -i NONE -l wezterm/tests/theme_sync.lua
```
