#!/bin/bash
# Usage: window_focus_or_swap.sh <direction>
# where direction is one of: east, west, north, south

dir="$1"

# Get current window frame (requires jq)
window=$(yabai -m query --windows --window)
win_x=$(echo "$window" | jq '.frame.x')
win_y=$(echo "$window" | jq '.frame.y')
win_w=$(echo "$window" | jq '.frame.w')
win_h=$(echo "$window" | jq '.frame.h')

# Get current display frame
display=$(yabai -m query --displays --display)
disp_x=$(echo "$display" | jq '.frame.x')
disp_y=$(echo "$display" | jq '.frame.y')
disp_w=$(echo "$display" | jq '.frame.w')
disp_h=$(echo "$display" | jq '.frame.h')

# We'll allow a small tolerance (1 pixel)
tolerance=15

case "$dir" in
  east)
    win_right=$(echo "$win_x + $win_w" | bc)
    disp_right=$(echo "$disp_x + $disp_w" | bc)
    if (( $(echo "$win_right >= $disp_right - $tolerance" | bc -l) )); then
      # At east edge, swap left
      yabai -m window --swap west
    fi
    yabai -m window --focus east
    ;;
  west)
    if (( $(echo "$win_x <= $disp_x + $tolerance" | bc -l) )); then
      # At west edge, swap right
      yabai -m window --swap east
    fi
    yabai -m window --focus west
    ;;
  north)
    if (( $(echo "$win_y <= $disp_y + $tolerance" | bc -l) )); then
      # At north edge, swap south
      yabai -m window --swap south
    fi
    yabai -m window --focus north
    ;;
  south)
    win_bottom=$(echo "$win_y + $win_h" | bc)
    disp_bottom=$(echo "$disp_y + $disp_h" | bc)
    if (( $(echo "$win_bottom >= $disp_bottom - $tolerance" | bc -l) )); then
      # At south edge, swap north
      yabai -m window --swap north
    fi
    yabai -m window --focus south
    ;;
  *)
    echo "Unknown direction: $dir"
    exit 1
    ;;
esac

