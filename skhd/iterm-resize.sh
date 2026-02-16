#!/bin/bash

# fractional change
# Only run for iTerm2
APP_NAME=$(yabai -m query --windows --window | jq -r '.app')[ "$APP_NAME" != "iTerm2" ] && exit 0

# fraction of the display width
TARGET_FRACTION=$1

# get window width
WINDOW_WIDTH=$(yabai -m query --windows --window | jq '.frame.w')

# get display width the window is on
DISPLAY_INDEX=$(yabai -m query --windows --window | jq '.display')
DISPLAY_WIDTH=$(yabai -m query --displays | jq ".[] | select(.index==$DISPLAY_INDEX) | .frame.w")

# compute target width
TARGET_WIDTH=$(echo "$DISPLAY_WIDTH * $TARGET_FRACTION" | bc)

# compute resize delta
RESIZE_AMOUNT=$(echo "$WINDOW_WIDTH - $TARGET_WIDTH" | bc)
RESIZE_AMOUNT_INT=$(printf "%.0f" "$RESIZE_AMOUNT")

if [ "$RESIZE_AMOUNT_INT" -gt 0 ]; then
  yabai -m window --resize right:-"$RESIZE_AMOUNT_INT":0
elif [ "$RESIZE_AMOUNT_INT" -lt 0 ]; then
  yabai -m window --resize right:$(( -RESIZE_AMOUNT_INT )):0
fi
