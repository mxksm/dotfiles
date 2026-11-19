local M = {}

local function blend(bg, fg, amount)
  local channels = {}
  for i = 2, 6, 2 do
    local a, b = tonumber(bg:sub(i, i + 1), 16), tonumber(fg:sub(i, i + 1), 16)
    channels[#channels + 1] = math.floor(a + (b - a) * amount + 0.5)
  end
  return string.format('#%02x%02x%02x', channels[1], channels[2], channels[3])
end

-- The same rectangle, neutral bar, and softer hover for presets and editor
-- palettes. Only tab colors change; terminal selections and ANSI colors stay intact.
function M.for_palette(colors)
  local bg, fg = colors.background:lower(), colors.foreground:lower()
  local function state(background, foreground, intensity)
    return { bg_color = background, fg_color = foreground, intensity = intensity or 'Normal',
      underline = 'None', italic = false, strikethrough = false }
  end
  return {
    background = bg, inactive_tab_edge = bg, inactive_tab_edge_hover = bg,
    active_tab = state(blend(bg, fg, 0.14), fg, 'Bold'),
    inactive_tab = state(bg, blend(bg, fg, 0.65)),
    inactive_tab_hover = state(blend(bg, fg, 0.07), fg),
    new_tab = state(bg, blend(bg, fg, 0.65)),
    new_tab_hover = state(blend(bg, fg, 0.07), fg),
  }
end

function M.with_tabs(colors)
  local result = {}
  for key, value in pairs(colors) do result[key] = value end
  result.tab_bar = M.for_palette(colors)
  return result
end

return M
