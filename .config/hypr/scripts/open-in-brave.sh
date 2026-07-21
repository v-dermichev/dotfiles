#!/bin/bash
# Close active scratchpad, switch to workspace 1, open URL in Brave Default profile

WS=$(hyprctl monitors -j | jq -r '.[].specialWorkspace.name' | grep -v '^$' | head -1)
[ -n "$WS" ] && hyprctl dispatch "hl.dsp.workspace.toggle_special(\"${WS#special:}\")"

if pgrep -x brave >/dev/null; then
    hyprctl dispatch "hl.dsp.focus({ workspace = 1 })"
    brave --profile-directory=Default "$@"
else
    hyprctl dispatch "hl.dsp.exec_cmd(\"brave --profile-directory=Default $*\", { workspace = \"1\" })"
fi
