#!/bin/bash
STATE_FILE="/tmp/hypr-split-state"
STATE=$(cat $STATE_FILE 2>/dev/null || echo "H")

if [ "$STATE" = "V" ]; then
  echo '{"text": "⬒ V", "tooltip": "Dwindle: Vertical split", "class": "vertical"}'
else
  echo '{"text": "⬓ H", "tooltip": "Dwindle: Horizontal split", "class": "horizontal"}'
fi
