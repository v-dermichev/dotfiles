#!/bin/bash
STATE_FILE="/tmp/hypr-split-state"

hyprctl dispatch layoutmsg togglesplit
# flip state
if [ "$(cat $STATE_FILE 2>/dev/null)" = "V" ]; then
  echo "H" > $STATE_FILE
else
  echo "V" > $STATE_FILE
fi

# signal waybar to refresh
pkill -RTMIN+8 waybar
