#!/bin/bash
# Switch to a named workspace and launch the app if it has no window there yet.
# Other windows sharing the workspace are ignored, so the app is restored even
# when the workspace is still occupied.
#
# Usage: workspace-launch.sh [-c CLASS_REGEX] <workspace-name> <command> [args...]
#
# The window class is matched case-insensitively against CLASS_REGEX, defaulting
# to the command's basename anchored on both ends (neovide -> ^neovide$). Pass
# -c when a program's class differs from its executable name.

CLASS_RE=""
if [ "$1" = "-c" ]; then
    CLASS_RE="$2"
    shift 2
fi

WS_NAME="$1"
shift
CMD=("$@")

hyprctl dispatch "hl.dsp.focus({ workspace = \"name:$WS_NAME\" })"

if [ ${#CMD[@]} -eq 0 ]; then
    exit 0
fi

if [ -z "$CLASS_RE" ]; then
    CLASS_RE="^$(basename "${CMD[0]}")\$"
fi

COUNT=$(hyprctl clients -j | jq --arg ws "$WS_NAME" --arg re "$CLASS_RE" \
    '[.[] | select(.workspace.name == $ws and (.class | test($re; "i")))] | length')

if [ "$COUNT" -eq 0 ]; then
    "${CMD[@]}" &
fi
