#!/bin/bash
# Watch Hyprland events and signal waybar when workspace/scratchpad state changes
# Replaces 1-second polling on 6 modules

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
LAST_SIGNAL=0

while true; do
    socat -u "UNIX-CONNECT:$SOCKET" - 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            workspace\>\>*|createworkspace*|destroyworkspace*|openwindow*|closewindow*|movewindow*|special*)
                NOW=$(date +%s%N | cut -c1-13)
                if (( NOW - LAST_SIGNAL > 100 )); then
                    LAST_SIGNAL=$NOW
                    pkill -RTMIN+13 waybar
                fi
                ;;
        esac
    done
    sleep 1
done
