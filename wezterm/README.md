# WezTerm themes

Neovim drives the terminal palette while it is active. Choose any NvChad theme
with `Space th`: its background, foreground, and terminal colors also apply to
WezTerm, including the padding and tabs. Previewing a theme updates the terminal;
Escape restores the previous theme. The shell keeps the chosen palette after
Neovim exits. Active tabs use a subtle theme-colored background tint and full
foreground color; inactive tabs use muted labels against the terminal background.

The Option+number shortcuts select matching themes in WezTerm and local Neovim
sessions: 1 Flexoki Dark, 2 Monokai Midnight, 3 Slate, 4 Tokyo Dracula, 5 Cocoa,
8 Gruvbox Light, 9 Catppuccin Latte, and 0 Paper White. Running editors update
immediately; a choice made from a shell also applies when Neovim next starts.
Neovim sends its full palette back, just as it does when using `Space th`.
The request is consumed once, so a later choice in Neovim's picker stays selected.

The theme picker starts in normal mode (`j`/`k` to preview, `i` to search).
The empty part of Neovim’s buffer bar shares the editor background.

Neovim must have transparency disabled for its theme to supply a background.
The integration lives in `nvim/lua/configs/wezterm_theme.lua` and
`wezterm/nvim_theme.lua`. Restart existing Neovim sessions after updating it.

The last palette is saved locally in ignored `.theme-state.json`; choosing themes
no longer edits tracked configuration. `.last_theme` is only a fallback for
installations without local state. Sioyek remains independently themed.

Shortcut requests use ignored `.theme-request.json`. WezTerm supplies its path
through `WEZTERM_THEME_REQUEST`; existing shells fall back to
`$XDG_CONFIG_HOME/wezterm` (or `~/.config/wezterm`). This bridge is local to each
laptop and does not send keystrokes or commands into terminal applications.

Run the integration regression check from the dotfiles root:

```sh
NVIM_LOG_FILE=/tmp/wezterm-theme-test.log nvim --headless -u NONE -i NONE -l wezterm/tests/theme_sync.lua
```

On macOS, new shells receive an empty `PROMPT_EOL_MARK` to suppress zsh’s
standalone `%` marker during startup resizing. Partial command output is still
preserved before the next prompt; this setting does not clear terminal output.
