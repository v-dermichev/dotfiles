#!/bin/bash
# Uses env vars: HYPR_INTERNAL, HYPR_EXTERNAL, HYPR_INTERNAL_MODE

INT="${HYPR_INTERNAL:-eDP-1}"
EXT="${HYPR_EXTERNAL:-HDMI-A-1}"
MODE="${HYPR_INTERNAL_MODE:-1920x1080@144}"
PAUSE_FILE="/tmp/monitor-watcher-paused"

# Only toggle if external monitor is connected
if ! hyprctl monitors all -j | jq -e --arg n "$EXT" 'any(.[]; .name == $n)' >/dev/null; then
    notify-send "Monitor" "External monitor not connected"
    exit 1
fi

# Check current state of internal monitor (authoritative disabled flag, not listing presence)
if [ "$(hyprctl monitors all -j | jq -r --arg n "$INT" '.[] | select(.name == $n) | .disabled')" = "false" ]; then
    # Disabling — resume watcher
    rm -f "$PAUSE_FILE"
    hyprctl eval "hl.monitor({ output = \"$INT\", disabled = true })"
    notify-send "Monitor" "Internal display disabled"
else
    # Enabling — pause watcher so it doesn't re-disable
    touch "$PAUSE_FILE"
    hyprctl eval "hl.monitor({ output = \"$INT\", mode = \"$MODE\", position = \"0x0\", scale = 1, disabled = false })"
    notify-send "Monitor" "Internal display enabled"
fi
