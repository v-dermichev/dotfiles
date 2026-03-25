#!/bin/bash
# Set a random wallpaper from starred list only

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
STARRED_FILE="$WALLPAPER_DIR/.starred"
STATE_FILE="/tmp/current-wallpaper"

[ -f "$STARRED_FILE" ] || exit 1

# Filter to only existing files
IMG=$(while IFS= read -r line; do [ -f "$line" ] && echo "$line"; done < "$STARRED_FILE" | shuf -n 1)

[ -z "$IMG" ] && exit 1

echo "$IMG" > "$STATE_FILE"
swww img "$IMG" --transition-type fade --transition-duration 1

pkill -RTMIN+11 waybar
