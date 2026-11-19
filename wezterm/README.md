# WezTerm themes

Neovim drives the terminal palette while it is active. Choose any NvChad theme
with `Space th`: its background, foreground, and terminal colors also apply to
WezTerm, including the padding and tabs. Previewing a theme updates the terminal;
Escape restores the previous theme. The shell keeps the chosen palette after
Neovim exits. Active tabs use a subtle theme-colored background tint and full
foreground color; inactive tabs use muted labels against the terminal background.

The Option+number shortcuts still select the presets in `keys.lua`. They change
the terminal palette, not Neovim’s selected theme. That choice survives focus
changes and Neovim restarts. Changing the theme inside Neovim resumes syncing;
simply returning to Neovim does not override a manually selected terminal preset.

The theme picker starts in normal mode (`j`/`k` to preview, `i` to search).
The empty part of Neovim’s buffer bar shares the editor background.

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

On macOS, new shells receive an empty `PROMPT_EOL_MARK` to suppress zsh’s
standalone `%` marker during startup resizing. Partial command output is still
preserved before the next prompt; this setting does not clear terminal output.
