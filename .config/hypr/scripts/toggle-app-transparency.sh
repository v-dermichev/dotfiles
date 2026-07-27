#!/bin/bash
# Toggle window transparency for kitty and neovide together, persisting the
# choice so newly started instances match.
#
# Usage: toggle-app-transparency.sh [toggle|on|off]

ON_OPACITY="${APP_ON_OPACITY:-0.92}"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/app-transparency"
KITTY_OPACITY_CONF="$HOME/.config/kitty/opacity.conf"
ACTION="${1:-toggle}"

mkdir -p "$(dirname "$STATE_FILE")"

current_state() {
    [ "$(cat "$STATE_FILE" 2>/dev/null)" = "off" ] && echo off || echo on
}

apply() {
    local state="$1" opacity
    [ "$state" = "off" ] && opacity=1.0 || opacity="$ON_OPACITY"

    printf '%s\n' "$state" >"$STATE_FILE"

    printf 'background_opacity %s\n' "$opacity" >"$KITTY_OPACITY_CONF"
    pkill -SIGUSR1 kitty 2>/dev/null

    # neovide reads the state file at startup; running instances need pushing.
    for sock in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/nvim.*; do
        [ -S "$sock" ] || continue
        if [ "$(nvim --headless --server "$sock" --remote-expr 'exists("g:neovide")' 2>/dev/null)" = "1" ]; then
            nvim --headless --server "$sock" \
                --remote-expr "execute('let g:neovide_opacity = $opacity')" >/dev/null 2>&1
        fi
    done
}

case "$ACTION" in
    on | off) apply "$ACTION" ;;
    toggle)
        if [ "$(current_state)" = "on" ]; then apply off; else apply on; fi
        ;;
    *)
        echo "usage: $(basename "$0") [toggle|on|off]" >&2
        exit 2
        ;;
esac
