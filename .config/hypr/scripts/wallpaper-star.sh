#!/bin/bash
# Toggle star status of current wallpaper

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
STARRED_FILE="$WALLPAPER_DIR/.starred"
STATE_FILE="/tmp/current-wallpaper"

touch "$STARRED_FILE"
[ -f "$STATE_FILE" ] || exit 1

CURRENT=$(cat "$STATE_FILE")
[ -z "$CURRENT" ] && exit 1

if grep -qxF "$CURRENT" "$STARRED_FILE"; then
    grep -vxF "$CURRENT" "$STARRED_FILE" > "$STARRED_FILE.tmp"
    mv "$STARRED_FILE.tmp" "$STARRED_FILE"
else
    echo "$CURRENT" >> "$STARRED_FILE"
fi

pkill -RTMIN+11 waybar
