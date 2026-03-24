#!/bin/bash

# Only toggle if external monitor is connected
if ! hyprctl monitors | grep -q "HDMI-A-1"; then
    notify-send "Monitor" "External monitor not connected"
    exit 1
fi

# Check current state of internal monitor
if hyprctl monitors | grep -q "eDP-1"; then
    # Currently enabled, disable it
    hyprctl keyword monitor "eDP-1, disable"
    notify-send "Monitor" "Internal display disabled"
else
    # Currently disabled, enable it
    hyprctl keyword monitor "eDP-1, 1920x1080@144, 0x0, 1"
    notify-send "Monitor" "Internal display enabled"
fi
