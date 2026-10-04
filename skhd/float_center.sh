#!/bin/sh
# Usage: sh float_center.sh <width-percent> <height-percent>
# Percentages use the full display frame, including reserved screen space.
set -eu

if [ "$#" -ne 2 ] || ! jq -en --arg w "${1-}" --arg h "${2-}" '
    [$w, $h] | map(tonumber) | all(. > 0 and . <= 100)
' >/dev/null 2>&1; then
    echo "Usage: $0 <width-percent> <height-percent> (each > 0 and <= 100)" >&2
    exit 1
fi

window=$(yabai -m query --windows --window)
id=$(printf '%s' "$window" | jq -er '.id')
display=$(printf '%s' "$window" | jq -er '.display')

yabai -m window "$id" --toggle float

# A second invocation returns the window to tiling.
window=$(yabai -m query --windows --window "$id")
[ "$(printf '%s' "$window" | jq -r '."is-floating"')" = true ] || exit 0

frame=$(yabai -m query --displays --display "$display")
geometry=$(printf '%s' "$frame" | jq -er --arg wp "$1" --arg hp "$2" '
    .frame |
    (.w * ($wp | tonumber) / 100 | round) as $w |
    (.h * ($hp | tonumber) / 100 | round) as $h |
    [$w, $h,
     (.x + (.w - $w) / 2 | round),
     (.y + (.h - $h) / 2 | round)] | @tsv
')
printf '%s\n' "$geometry" | while read -r w h x y; do
    # Growing a right-hand tile before moving it can hit macOS screen limits.
    # Move first and wait for the cached position before requesting the size.
    # If the old size prevents that move, resizing makes room for the next pass.
    pass=0
    while [ "$pass" -lt 4 ]; do
        yabai -m window "$id" --move "abs:$x:$y"
        poll=0
        while [ "$poll" -lt 10 ]; do
            sleep 0.05
            current=$(yabai -m query --windows --window "$id")
            if printf '%s' "$current" | jq -e --argjson x "$x" --argjson y "$y" '
                ((.frame.x - $x) | fabs) <= 1 and
                ((.frame.y - $y) | fabs) <= 1
            ' >/dev/null; then
                break
            fi
            poll=$((poll + 1))
        done

        yabai -m window "$id" --resize "abs:$w:$h"
        poll=0
        while [ "$poll" -lt 10 ]; do
            sleep 0.05
            current=$(yabai -m query --windows --window "$id")
            if printf '%s' "$current" | jq -e \
                --argjson w "$w" --argjson h "$h" \
                --argjson x "$x" --argjson y "$y" '
                ((.frame.w - $w) | fabs) <= 1 and
                ((.frame.h - $h) | fabs) <= 1 and
                ((.frame.x - $x) | fabs) <= 1 and
                ((.frame.y - $y) | fabs) <= 1
            ' >/dev/null; then
                exit 0
            fi
            poll=$((poll + 1))
        done
        pass=$((pass + 1))
    done

    actual=$(printf '%s' "$current" | jq -c '.frame')
    echo "Window $id could not reach ${w}x${h} at $x,$y; actual frame: $actual" >&2
    exit 1
done
