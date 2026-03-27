#!/bin/bash
# Watch Hyprland events and signal waybar when workspace/scratchpad state changes
# Replaces 1-second polling on 6 modules

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

while true; do
    socat -u "UNIX-CONNECT:$SOCKET" - 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            activewindow*|workspace*|special*|openwindow*|closewindow*)
                pkill -RTMIN+13 waybar
                ;;
        esac
    done
    sleep 1
done
