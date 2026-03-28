#!/bin/bash

# Get a list of all visible applications on the current space
# (Ignores minimized or hidden windows)
apps=$(yabai -m query --windows --space | jq -r '.[] | select(."is-hidden" == false and ."is-minimized" == false) | .app' | tr '[:upper:]' '[:lower:]')

# 1. Check if there are any apps open that are NOT Kitty or Sioyek
other_apps=$(echo "$apps" | grep -vE '^(kitty|sioyek)$')

# 2. Check if both Kitty and Sioyek are currently present on the screen
has_kitty=$(echo "$apps" | grep -c 'kitty')
has_sioyek=$(echo "$apps" | grep -c 'sioyek')

# If there are NO other apps, AND we have at least one Kitty AND one Sioyek
if [[ -z "$other_apps" ]] && (( has_kitty > 0 )) && (( has_sioyek > 0 )); then
    # Set gap to 0
    yabai -m config window_gap 0
else
    # Set gap back to default 10
    yabai -m config window_gap 10
fi
