#!/bin/bash
# Watch Hyprland events and re-disable internal monitor whenever monitors change
# Handles: DPMS wake, suspend/resume, HDMI hotplug
# Uses env vars: HYPR_INTERNAL, HYPR_EXTERNAL, HYPR_INTERNAL_MODE

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
INT="${HYPR_INTERNAL:-eDP-1}"
EXT="${HYPR_EXTERNAL:-HDMI-A-1}"
MODE="${HYPR_INTERNAL_MODE:-1920x1080@144}"

PAUSE_FILE="/tmp/monitor-watcher-paused"

handle_monitor_change() {
    sleep 0.5
    [ -f "$PAUSE_FILE" ] && return
    if hyprctl monitors | grep -q "$EXT"; then
        hyprctl keyword monitor "$INT, disable"
    else
        hyprctl keyword monitor "$INT, $MODE, 0x0, 1"
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
