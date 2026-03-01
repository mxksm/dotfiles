#!/bin/bash

TARGET_FRACTION=$1

# find an iTerm2 window (pick the first one)
WINDOW_ID=$(yabai -m query --windows | jq -r '.[] | select(.app=="iTerm2") | .id' | head -n 1)

# if no iTerm2 window exists, exit quietly
[ -z "$WINDOW_ID" ] && exit 0

# get window info
WINDOW_WIDTH=$(yabai -m query --windows --window "$WINDOW_ID" | jq '.frame.w')
DISPLAY_INDEX=$(yabai -m query --windows --window "$WINDOW_ID" | jq '.display')
DISPLAY_WIDTH=$(yabai -m query --displays | jq ".[] | select(.index==$DISPLAY_INDEX) | .frame.w")

TARGET_WIDTH=$(echo "$DISPLAY_WIDTH * $TARGET_FRACTION" | bc)
RESIZE_AMOUNT=$(echo "$WINDOW_WIDTH - $TARGET_WIDTH" | bc)
RESIZE_AMOUNT_INT=$(printf "%.0f" "$RESIZE_AMOUNT")

if [ "$RESIZE_AMOUNT_INT" -gt 0 ]; then
  yabai -m window "$WINDOW_ID" --resize right:-"$RESIZE_AMOUNT_INT":0
elif [ "$RESIZE_AMOUNT_INT" -lt 0 ]; then
  yabai -m window "$WINDOW_ID" --resize right:$(( -RESIZE_AMOUNT_INT )):0
fi
