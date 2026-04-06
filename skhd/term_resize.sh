#!/bin/bash

# The ideal width-to-height ratio for Sioyek passed as an argument
TARGET_RATIO=$1

# How many pixels of inaccuracy we are willing to accept
TOLERANCE=2

# Find the Sioyek window
SIOYEK_ID=$(yabai -m query --windows | jq -r '.[] | select(.app | test("sioyek"; "i")) | .id' | head -n 1)

# If no Sioyek window exists, exit quietly
[ -z "$SIOYEK_ID" ] && exit 0

# Get Sioyek's current info
SIOYEK_INFO=$(yabai -m query --windows --window "$SIOYEK_ID")

# Extract width/height and round them to integers
SIOYEK_WIDTH=$(printf "%.0f" $(echo "$SIOYEK_INFO" | jq '.frame.w'))
SIOYEK_HEIGHT=$(printf "%.0f" $(echo "$SIOYEK_INFO" | jq '.frame.h'))

# Calculate target width
TARGET_WIDTH=$(printf "%.0f" $(echo "$SIOYEK_HEIGHT * $TARGET_RATIO" | bc -l))

# Calculate the exact difference using native bash math
RESIZE_AMOUNT=$(( SIOYEK_WIDTH - TARGET_WIDTH ))

# Strip the negative sign to get the absolute difference for the tolerance check
ABS_RESIZE_AMOUNT=${RESIZE_AMOUNT#-}

# If the difference is within our tolerance, do nothing and exit
if [ "$ABS_RESIZE_AMOUNT" -le "$TOLERANCE" ]; then
    exit 0
fi

# Compensate for yabai eating exactly 1 pixel during resizes
if [ "$RESIZE_AMOUNT" -gt 0 ]; then
    RESIZE_AMOUNT=$(( RESIZE_AMOUNT + 1 ))
elif [ "$RESIZE_AMOUNT" -lt 0 ]; then
    RESIZE_AMOUNT=$(( RESIZE_AMOUNT - 1 ))
fi

# Execute the resize
yabai -m window "$SIOYEK_ID" --resize left:"$RESIZE_AMOUNT":0
