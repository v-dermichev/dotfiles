#!/bin/bash
# Toggle a named special workspace (lua IPC form).
# Exists so notification-daemon exec strings need no nested quoting: swaync
# doesn't shell-parse its exec value, so quotes in
#   hyprctl dispatch 'hl.dsp.workspace.toggle_special("name")'
# reach Hyprland mangled and the dispatch toggles the UNNAMED special
# (creating the phantom "special:special" workspace / {name} waybar tab).
[ -n "$1" ] || exit 1
exec hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$1\")"
