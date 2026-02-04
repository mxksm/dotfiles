#!/bin/bash

# Only run for iTerm2
APP_NAME=$(yabai -m query --windows --window | jq -r '.app')
if [ "$APP_NAME" != "iTerm2" ]; then
    exit 0
fi

TARGET_WIDTH=786              # <- set your desired width here
WINDOW_WIDTH=$(yabai -m query --windows --window | jq '.frame."w"')
WINDOW_WIDTH=$(echo "$WINDOW_WIDTH" | tr -d '"')

# compute difference (bc can handle decimals)
RESIZE_AMOUNT=$(echo "$WINDOW_WIDTH - $TARGET_WIDTH" | bc)

# convert to integer pixels (drop fractional part)
RESIZE_AMOUNT_INT=$(echo "$RESIZE_AMOUNT" | cut -d'.' -f1)

if [ "$RESIZE_AMOUNT_INT" -gt 0 ]; then
  yabai -m window --resize right:-"$RESIZE_AMOUNT_INT":0
elif [ "$RESIZE_AMOUNT_INT" -lt 0 ]; then
  # window is too narrow → expand to the right (use absolute value)
  ABS_RESIZE=$(( RESIZE_AMOUNT_INT * -1 ))
  yabai -m window --resize right:"$ABS_RESIZE":0
fi

