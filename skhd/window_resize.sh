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
tolerance_x=15
tolerance_y=45

case "$dir" in
  l)
    win_right=$(echo "$win_x + $win_w" | bc)
    disp_right=$(echo "$disp_x + $disp_w" | bc)
    if (( $(echo "$win_right >= $disp_right - $tolerance_x" | bc -l) )); then
      # focused window on the right
      yabai -m window --resize left:50:0 
    else
      yabai -m window --resize right:50:0 
    fi
    ;;
  h)
    if (($(echo "$win_x <= $disp_x + $tolerance_x" | bc -l) )); then
      # focused window on the left
      yabai -m window --resize right:-50:0 
    else
      yabai -m window --resize left:-50:0 
    fi
    ;;
  j)
    if (( $(echo "$win_y <= $disp_y + $tolerance_y" | bc -l) )); then
      # focused window at the bottom
      yabai -m window --resize bottom:0:50
    else
      # focused window at the top
      yabai -m window --resize top:0:50
    fi
    ;;
  k)
    win_bottom=$(echo "$win_y + $win_h" | bc)
    disp_bottom=$(echo "$disp_y + $disp_h" | bc)
    if (( $(echo "$win_bottom >= $disp_bottom - $tolerance_y" | bc -l) )); then
      # focused window at the bottom
      yabai -m window --resize top:0:-50
    else
      # focused window at the top
      yabai -m window --resize bottom:0:-50
    fi
    ;;
  *)
    echo "Unknown direction: $dir"
    exit 1
    ;;
esac
