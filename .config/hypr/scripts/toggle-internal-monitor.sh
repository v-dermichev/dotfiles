#!/bin/bash
# Uses env vars: HYPR_INTERNAL, HYPR_EXTERNAL, HYPR_INTERNAL_MODE

INT="${HYPR_INTERNAL:-eDP-1}"
EXT="${HYPR_EXTERNAL:-HDMI-A-1}"
MODE="${HYPR_INTERNAL_MODE:-1920x1080@144}"
PAUSE_FILE="/tmp/monitor-watcher-paused"

# Only toggle if external monitor is connected
if ! hyprctl monitors | grep -q "$EXT"; then
    notify-send "Monitor" "External monitor not connected"
    exit 1
fi

# Check current state of internal monitor
if hyprctl monitors | grep -q "$INT"; then
    # Disabling — resume watcher
    rm -f "$PAUSE_FILE"
    hyprctl keyword monitor "$INT, disable"
    notify-send "Monitor" "Internal display disabled"
else
    # Enabling — pause watcher so it doesn't re-disable
    touch "$PAUSE_FILE"
    hyprctl keyword monitor "$INT, $MODE, 0x0, 1"
    notify-send "Monitor" "Internal display enabled"
fi
