#!/bin/bash
# Set the internal panel's state and persist the choice, so the Hyprland config
# re-declares the same state on its next load rather than reverting to a default.
#
# Usage: toggle-internal-monitor.sh [toggle|on|off|auto]
#   toggle  flip the current state (default; bound to Super+P)
#   on      force the panel on, even alongside the external display
#   off     turn the panel off (refused when no external display is attached)
#   auto    follow the external display: off while attached, on otherwise
#
# Uses env vars: HYPR_INTERNAL, HYPR_EXTERNAL, HYPR_INTERNAL_MODE

INT="${HYPR_INTERNAL:-eDP-1}"
EXT="${HYPR_EXTERNAL:-HDMI-A-1}"
MODE="${HYPR_INTERNAL_MODE:-1920x1080@144}"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
STATE_FILE="$STATE_DIR/internal-monitor"
ACTION="${1:-toggle}"

mkdir -p "$STATE_DIR"

# Read DRM directly rather than asking Hyprland: this must give the same answer
# the config sees when it re-applies the state on load.
external_connected() {
    grep -qx connected /sys/class/drm/*-"$EXT"/status 2>/dev/null
}

enable_internal() {
    printf 'enabled\n' >"$STATE_FILE"
    hyprctl eval "hl.monitor({ output = \"$INT\", mode = \"$MODE\", position = \"0x0\", scale = 1, disabled = false })"
}

disable_internal() {
    printf 'disabled\n' >"$STATE_FILE"
    hyprctl eval "hl.monitor({ output = \"$INT\", disabled = true })"
}

# Authoritative flag, not presence in the listing: right after a disable the
# plain listing can still be stale.
internal_is_on() {
    [ "$(hyprctl monitors all -j | jq -r --arg n "$INT" '.[] | select(.name == $n) | .disabled')" = "false" ]
}

case "$ACTION" in
    on)
        enable_internal
        notify-send "Monitor" "Internal display enabled"
        ;;
    off)
        if ! external_connected; then
            notify-send "Monitor" "External monitor not connected"
            exit 1
        fi
        disable_internal
        notify-send "Monitor" "Internal display disabled"
        ;;
    auto)
        if external_connected; then
            disable_internal
        else
            enable_internal
        fi
        ;;
    toggle)
        if internal_is_on; then
            if ! external_connected; then
                notify-send "Monitor" "External monitor not connected"
                exit 1
            fi
            disable_internal
            notify-send "Monitor" "Internal display disabled"
        else
            enable_internal
            notify-send "Monitor" "Internal display enabled"
        fi
        ;;
    *)
        echo "usage: $(basename "$0") [toggle|on|off|auto]" >&2
        exit 2
        ;;
esac
