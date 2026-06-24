#!/bin/bash
# Usage: window_focus_or_swap.sh <direction>
# where direction is one of: east, west, north, south

dir="$1"
swap="$2"

focus_edge_window_on_adjacent_display() {
  local direction="$1"
  local displays current_display_id current_display
  local current_center_x target_display_index target_window_id

  displays=$(yabai -m query --displays)
  current_display_id=$(yabai -m query --displays --display | jq '.id')
  current_display=$(echo "$displays" | jq ".[] | select(.id == $current_display_id)")
  current_center_x=$(echo "$current_display" | jq '.frame.x + (.frame.w / 2)')

  case "$direction" in
    east)
      target_display_index=$(
        echo "$displays" |
          jq -r --argjson current_center_x "$current_center_x" '
            map(. + { center_x: (.frame.x + (.frame.w / 2)) })
            | map(select(.center_x > $current_center_x))
            | sort_by(.center_x)
            | first
            | .index // empty
          '
      )
      [[ -z "$target_display_index" ]] && return 1

      target_window_id=$(
        yabai -m query --windows |
          jq -r --argjson display "$target_display_index" '
            map(select(.display == $display and ."is-visible" == true and ."is-minimized" == false))
            | sort_by(.frame.x, .frame.y)
            | first
            | .id // empty
          '
      )
      ;;
    west)
      target_display_index=$(
        echo "$displays" |
          jq -r --argjson current_center_x "$current_center_x" '
            map(. + { center_x: (.frame.x + (.frame.w / 2)) })
            | map(select(.center_x < $current_center_x))
            | sort_by(.center_x)
            | reverse
            | first
            | .index // empty
          '
      )
      [[ -z "$target_display_index" ]] && return 1

      target_window_id=$(
        yabai -m query --windows |
          jq -r --argjson display "$target_display_index" '
            map(select(.display == $display and ."is-visible" == true and ."is-minimized" == false))
            | sort_by((.frame.x + .frame.w), .frame.y)
            | reverse
            | first
            | .id // empty
          '
      )
      ;;
    *)
      return 1
      ;;
  esac

  [[ -z "$target_window_id" ]] && return 1
  yabai -m window --focus "$target_window_id"
}

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
  east)
    win_right=$(echo "$win_x + $win_w" | bc)
    disp_right=$(echo "$disp_x + $disp_w" | bc)
    if (( $(echo "$win_right >= $disp_right - $tolerance_x" | bc -l) )) && [[ "$swap" == "true" ]]; then
      # At east edge, swap left
      yabai -m window --swap west
    fi
    yabai -m window --focus east 2>/dev/null || {
      [[ "$swap" != "true" ]] && focus_edge_window_on_adjacent_display east
    }
    ;;
  west)
    if (( $(echo "$win_x <= $disp_x + $tolerance_x" | bc -l) )) && [[ "$swap" == "true" ]]; then
      # At west edge, swap right
      yabai -m window --swap east
    fi
    yabai -m window --focus west 2>/dev/null || {
      [[ "$swap" != "true" ]] && focus_edge_window_on_adjacent_display west
    }
    ;;
  north)
    if (( $(echo "$win_y <= $disp_y + $tolerance_y" | bc -l) )) && [[ "$swap" == "true" ]]; then
      # At north edge, swap south
      echo "here"
      yabai -m window --swap south
    fi
    yabai -m window --focus north
    ;;
  south)
    win_bottom=$(echo "$win_y + $win_h" | bc)
    disp_bottom=$(echo "$disp_y + $disp_h" | bc)
    if (( $(echo "$win_bottom >= $disp_bottom - $tolerance_y" | bc -l) )) && [[ "$swap" == "true" ]]; then
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
