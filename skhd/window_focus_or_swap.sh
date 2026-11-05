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
  local windows neighbor target_window_id

  # Resolve the native directional candidate without changing focus. One window
  # snapshot also supplies the origin and our cross-display/wraparound fallback.
  windows=$(yabai -m query --windows) || return 1
  neighbor=$(yabai -m query --windows --window "$direction" 2>/dev/null) || neighbor=null

  target_window_id=$(
    jq -er --arg direction "$direction" --argjson neighbor "$neighbor" \
      --argjson tolerance_x "$tolerance_x" '
      def center_x: .frame.x + (.frame.w / 2);
      def center_y: .frame.y + (.frame.h / 2);
      def distance_y($origin): (center_y - ($origin | center_y)) | fabs;
      def is_ahead($origin):
        if $direction == "east" then
          center_x > (($origin | center_x) + $tolerance_x)
        else
          center_x < (($origin | center_x) - $tolerance_x)
        end;
      def in_direction_order($origin):
        sort_by(center_x, distance_y($origin))
        | if $direction == "west" then reverse else . end;

      (map(select(."has-focus" == true)) | first) as $origin
      | if $origin == null then
          empty
        elif $neighbor != null and $neighbor.id != $origin.id
          and ($neighbor.display != $origin.display or ($neighbor | is_ahead($origin))) then
          $neighbor.id
        else
          [ .[] | select(
              .id != $origin.id
              and ."is-visible" == true
              and ."is-minimized" == false
              and ."is-floating" == false
            ) ]
          | in_direction_order($origin) as $windows
          | (($windows | map(select(is_ahead($origin))) | first)
              // ($windows | first))
          | .id // empty
        end
      ' <<< "$windows"
  ) || return 1

  [[ -n "$target_window_id" ]] || return 1
  yabai -m window --focus "$target_window_id"
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

# Geometry is needed only for vertical swaps, never ordinary focus changes.
tolerance_x=15
tolerance_y=45
if [[ "$swap" == "true" && ( "$dir" == "north" || "$dir" == "south" ) ]]; then
  window=$(yabai -m query --windows --window) || exit 1
  display=$(yabai -m query --displays --display) || exit 1
  read -r win_y win_h <<< "$(jq -r '[.frame.y, .frame.h] | @tsv' <<< "$window")"
  read -r disp_y disp_h <<< "$(jq -r '[.frame.y, .frame.h] | @tsv' <<< "$display")"
fi

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
    if [[ "$swap" == "true" ]] && (( $(echo "$win_y <= $disp_y + $tolerance_y" | bc -l) )); then
      # At north edge, swap south
      echo "here"
      yabai -m window --swap south
    fi
    yabai -m window --focus north
    ;;
  south)
    if [[ "$swap" == "true" ]] && (( $(echo "$win_y + $win_h >= $disp_y + $disp_h - $tolerance_y" | bc -l) )); then
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
