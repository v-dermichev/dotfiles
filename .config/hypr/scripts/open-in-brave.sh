#!/bin/bash
# Registered as the browser handler, so a URL means "open this link" -- go to the
# Brave window on workspace 1 and let it land there as a tab. No argument means a
# plain launch (the app launcher), which should open where the user already is.

if [ $# -eq 0 ]; then
    exec brave --profile-directory=Default --new-window
fi

# Close active scratchpad, switch to workspace 1, open URL in Brave Default profile
WS=$(hyprctl monitors -j | jq -r '.[].specialWorkspace.name' | grep -v '^$' | head -1)
[ -n "$WS" ] && hyprctl dispatch "hl.dsp.workspace.toggle_special(\"${WS#special:}\")"

if pgrep -x brave >/dev/null; then
    hyprctl dispatch "hl.dsp.focus({ workspace = 1 })"
    brave --profile-directory=Default "$@"
else
    hyprctl dispatch "hl.dsp.exec_cmd(\"brave --profile-directory=Default $*\", { workspace = \"1\" })"
fi
