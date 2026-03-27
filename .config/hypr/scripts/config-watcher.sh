#!/bin/bash
# Watch scratchpads.conf and workspaces.conf for changes
# Regenerates configs and reloads hyprland + waybar

HYPR_DIR="$HOME/.config/hypr"

regenerate() {
    CONF="$HYPR_DIR/scratchpads.conf" "$HYPR_DIR/scripts/generate-scratchpads.sh" >/dev/null 2>&1
    CONF="$HYPR_DIR/workspaces.conf" "$HYPR_DIR/scripts/generate-workspaces.sh" >/dev/null 2>&1
    "$HOME/.config/waybar/assemble-config.sh" >/dev/null 2>&1
    (pkill -x waybar 2>/dev/null; waybar &>/dev/null) &
}

# Initial generation
regenerate

# Watch for changes
while true; do
    inotifywait -q -e modify,create "$HYPR_DIR/scratchpads.conf" "$HYPR_DIR/workspaces.conf" "$HOME/.config/waybar/config.template.jsonc" 2>/dev/null
    sleep 0.1
    regenerate &
done
