#!/bin/bash
# Usage: window_focus_or_swap.sh <direction>
# where direction is one of: east, west, north, south

dir="$1"
swap="$2"

focus_cycle_neighbor() {
  local direction="$1"
  local fallback_current_window_id="$2"
  local current_window current_window_id target_window_id

  if [[ -n "$fallback_current_window_id" ]]; then
    current_window_id="$fallback_current_window_id"
  else
    current_window=$(yabai -m query --windows --window)
    current_window_id=$(echo "$current_window" | jq '.id')
  fi

  target_window_id=$(
    yabai -m query --windows |
      jq -r --argjson current "$current_window_id" --arg direction "$direction" '
        [
          .[]
          | select(
              ."is-visible" == true
              and ."is-minimized" == false
              and ."is-floating" == false
            )
        ]
        | sort_by((.frame.x + (.frame.w / 2)), (.frame.y + (.frame.h / 2)))
        as $windows
        | ($windows | map(.id) | index($current)) as $index
        | ($windows | length) as $count
        | if $index == null or $count < 2 then
            empty
          elif $direction == "east" then
            $windows[(($index + 1) % $count)].id
          else
            $windows[(($index - 1 + $count) % $count)].id
          end
      '
  )

  [[ -z "$target_window_id" ]] && return 1
  yabai -m window --focus "$target_window_id"
}

focus_horizontal_or_cycle() {
  local direction="$1"
  local original_window original_window_id original_display original_center_x
  local original_center_y focused_window focused_window_id focused_display focused_center_x
  local target_window_id

  original_window=$(yabai -m query --windows --window)
  original_window_id=$(echo "$original_window" | jq '.id')
  original_display=$(echo "$original_window" | jq '.display')
  original_center_x=$(echo "$original_window" | jq '.frame.x + (.frame.w / 2)')
  original_center_y=$(echo "$original_window" | jq '.frame.y + (.frame.h / 2)')

  if yabai -m window --focus "$direction" 2>/dev/null; then
    focused_window=$(yabai -m query --windows --window)
    focused_window_id=$(echo "$focused_window" | jq '.id')
    focused_display=$(echo "$focused_window" | jq '.display')
    focused_center_x=$(echo "$focused_window" | jq '.frame.x + (.frame.w / 2)')

    # Accept cross-display focus. On the same display, only accept it if the
    # chosen window is actually horizontally left/right of the original one.
    if [[ "$focused_window_id" != "$original_window_id" && "$focused_display" != "$original_display" ]]; then
      return 0
    fi

    case "$direction" in
      east)
        if (( $(echo "$focused_center_x > $original_center_x + $tolerance_x" | bc -l) )); then
          return 0
        fi
        ;;
      west)
        if (( $(echo "$focused_center_x < $original_center_x - $tolerance_x" | bc -l) )); then
          return 0
        fi
        ;;
    esac

    # yabai "succeeded" by moving vertically. Undo it and use our abstract
    # left/right cycle instead.
    yabai -m window --focus "$original_window_id" 2>/dev/null
  fi

  target_window_id=$(
    yabai -m query --windows |
      jq -r \
        --argjson current "$original_window_id" \
        --argjson origin_x "$original_center_x" \
        --argjson origin_y "$original_center_y" \
        --argjson tolerance_x "$tolerance_x" \
        --arg direction "$direction" '
          [
            .[]
            | select(
                .id != $current
                and ."is-visible" == true
                and ."is-minimized" == false
                and ."is-floating" == false
              )
            | . + {
                center_x: (.frame.x + (.frame.w / 2)),
                center_y: (.frame.y + (.frame.h / 2))
              }
          ] as $windows
          | if ($windows | length) == 0 then
              empty
            elif $direction == "east" then
              (
                $windows
                | map(select(.center_x > ($origin_x + $tolerance_x)))
                | sort_by(.center_x, ((.center_y - $origin_y) as $d | if $d < 0 then -$d else $d end))
                | first
              ) // (
                $windows
                | sort_by(.center_x, ((.center_y - $origin_y) as $d | if $d < 0 then -$d else $d end))
                | first
              )
              | .id // empty
            else
              (
                $windows
                | map(select(.center_x < ($origin_x - $tolerance_x)))
                | sort_by(.center_x, ((.center_y - $origin_y) as $d | if $d < 0 then -$d else $d end))
                | reverse
                | first
              ) // (
                $windows
                | sort_by(.center_x, ((.center_y - $origin_y) as $d | if $d < 0 then -$d else $d end))
                | reverse
                | first
              )
              | .id // empty
            end
        '
  )

  if [[ -n "$target_window_id" ]]; then
    yabai -m window --focus "$target_window_id"
    return $?
  fi

  return 1
}

swap_and_refocus() {
  local target="$1"
  local current_window_id
  local focus_partner_direction

  current_window_id=$(yabai -m query --windows --window | jq '.id')
  if yabai -m window --swap "$target"; then
    case "$target" in
      east) focus_partner_direction="west" ;;
      west) focus_partner_direction="east" ;;
      north) focus_partner_direction="south" ;;
      south) focus_partner_direction="north" ;;
      *) focus_partner_direction="" ;;
    esac

    [[ -n "$focus_partner_direction" ]] && yabai -m window --focus "$focus_partner_direction" 2>/dev/null
    sleep 0.03
    yabai -m window --focus "$current_window_id"
    return 0
  fi

  return 1
}

swap_with_cycle_neighbor() {
  local direction="$1"
  local current_window current_window_id target_window_id

  current_window=$(yabai -m query --windows --window)
  current_window_id=$(echo "$current_window" | jq '.id')

  target_window_id=$(
    yabai -m query --windows |
      jq -r --argjson current "$current_window_id" --arg direction "$direction" '
        [
          .[]
          | select(
              ."is-visible" == true
              and ."is-minimized" == false
              and ."is-floating" == false
            )
        ]
        | sort_by((.frame.x + (.frame.w / 2)), (.frame.y + (.frame.h / 2)))
        as $windows
        | ($windows | map(.id) | index($current)) as $index
        | ($windows | length) as $count
        | if $index == null or $count < 2 then
            empty
          elif $direction == "east" then
            $windows[(($index + 1) % $count)].id
          else
            $windows[(($index - 1 + $count) % $count)].id
          end
      '
  )

  [[ -z "$target_window_id" ]] && return 1
  if yabai -m window --swap "$target_window_id"; then
    yabai -m window --focus "$target_window_id" 2>/dev/null
    sleep 0.03
    yabai -m window --focus "$current_window_id"
    return 0
  fi

  return 1
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
    if [[ "$swap" == "true" ]]; then
      swap_and_refocus east 2>/dev/null || swap_with_cycle_neighbor east
    else
      focus_horizontal_or_cycle east
    fi
    ;;
  west)
    if [[ "$swap" == "true" ]]; then
      swap_and_refocus west 2>/dev/null || swap_with_cycle_neighbor west
    else
      focus_horizontal_or_cycle west
    fi
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
