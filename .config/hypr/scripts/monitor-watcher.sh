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
    if hyprctl monitors all -j | jq -e --arg n "$EXT" 'any(.[]; .name == $n)' >/dev/null; then
        hyprctl eval "hl.monitor({ output = \"$INT\", disabled = true })"
    else
        hyprctl eval "hl.monitor({ output = \"$INT\", mode = \"$MODE\", position = \"0x0\", scale = 1, disabled = false })"
    fi
}

# swaync's notification layer binds to an output at startup; when the output
# set changes it can be left rendering popups on a disabled screen while the
# center silently keeps collecting them. Restart to rebind. Only on real
# monitor add/remove — not DPMS wakes — since a restart drops popup history.
restart_swaync() {
    pkill -x swaync && setsid -f swaync >/dev/null 2>&1
}

while true; do
    socat -u "UNIX-CONNECT:$SOCKET" - 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            monitoradded*|monitorremoved*)
                handle_monitor_change
                restart_swaync
                ;;
            dpms\>\>1*)
                handle_monitor_change
                ;;
        esac
    done
    # Session ended (socket gone): exit instead of retrying forever as an orphan
    [ -S "$SOCKET" ] || exit 0
    sleep 1
done
