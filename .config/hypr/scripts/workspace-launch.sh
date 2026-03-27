#!/bin/bash
# Switch to named workspace, launch app if workspace is empty
# Usage: workspace-launch.sh <workspace-name> <command>

WS_NAME="$1"
shift
CMD="$@"

hyprctl dispatch workspace "name:$WS_NAME"

# Check if workspace has any windows
COUNT=$(hyprctl clients -j | jq "[.[] | select(.workspace.name == \"$WS_NAME\")] | length")

if [ "$COUNT" -eq 0 ] && [ -n "$CMD" ]; then
    $CMD &
fi
