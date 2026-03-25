#!/bin/bash
# Move current wallpaper to trash and pick a new one

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
TRASH_DIR="$WALLPAPER_DIR/.trash"
STARRED_FILE="$WALLPAPER_DIR/.starred"
STATE_FILE="/tmp/current-wallpaper"

mkdir -p "$TRASH_DIR"
[ -f "$STATE_FILE" ] || exit 1

CURRENT=$(cat "$STATE_FILE")
[ -z "$CURRENT" ] || [ ! -f "$CURRENT" ] && exit 1

# Remove from starred if present
if [ -f "$STARRED_FILE" ]; then
    grep -vxF "$CURRENT" "$STARRED_FILE" > "$STARRED_FILE.tmp"
    mv "$STARRED_FILE.tmp" "$STARRED_FILE"
fi

# Move to trash preserving filename
mv "$CURRENT" "$TRASH_DIR/"

# Pick a new one
~/.config/hypr/scripts/wallpaper-random.sh
