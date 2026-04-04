#!/bin/bash
# Close active scratchpad, switch to workspace 1, open URL in Brave Default profile

WS=$(hyprctl monitors -j | jq -r '.[].specialWorkspace.name' | grep -v '^$' | head -1)
[ -n "$WS" ] && hyprctl dispatch togglespecialworkspace "${WS#special:}"

if pgrep -x brave >/dev/null; then
    hyprctl dispatch workspace 1
    brave --profile-directory=Default "$@"
else
    hyprctl dispatch exec "[workspace 1] brave --profile-directory=Default $@"
fi
