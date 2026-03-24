#!/bin/bash
# Watch Hyprland events and re-disable eDP-1 whenever monitors change
# Handles: DPMS wake, suspend/resume, HDMI hotplug

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

handle_monitor_change() {
    sleep 0.5
    if hyprctl monitors | grep -q "HDMI-A-1"; then
        hyprctl keyword monitor "eDP-1, disable"
    else
        hyprctl keyword monitor "eDP-1, 1920x1080@144, 0x0, 1"
    fi
}

while true; do
    socat -u "UNIX-CONNECT:$SOCKET" - 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            monitoradded*|monitorremoved*|dpms\>\>1*)
                handle_monitor_change
                ;;
        esac
    done
    sleep 1
done
