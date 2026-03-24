#!/bin/bash
# Uses env vars: HYPR_INTERNAL, HYPR_EXTERNAL, HYPR_INTERNAL_MODE

INT="${HYPR_INTERNAL:-eDP-1}"
EXT="${HYPR_EXTERNAL:-HDMI-A-1}"
MODE="${HYPR_INTERNAL_MODE:-1920x1080@144}"

# Only toggle if external monitor is connected
if ! hyprctl monitors | grep -q "$EXT"; then
    notify-send "Monitor" "External monitor not connected"
    exit 1
fi

# Check current state of internal monitor
if hyprctl monitors | grep -q "$INT"; then
    hyprctl keyword monitor "$INT, disable"
    notify-send "Monitor" "Internal display disabled"
else
    hyprctl keyword monitor "$INT, $MODE, 0x0, 1"
    notify-send "Monitor" "Internal display enabled"
fi
