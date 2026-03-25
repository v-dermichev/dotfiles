#!/bin/bash
# Set a random wallpaper from ~/Pictures/Wallpapers, excluding trashed ones

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
TRASH_DIR="$WALLPAPER_DIR/.trash"
STATE_FILE="/tmp/current-wallpaper"
STARRED_FILE="$WALLPAPER_DIR/.starred"

mkdir -p "$TRASH_DIR"
touch "$STARRED_FILE"

# Find all images, exclude .trash and .git dirs
IMG=$(find "$WALLPAPER_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) \
    -not -path "*/.trash/*" -not -path "*/.git/*" | shuf -n 1)

[ -z "$IMG" ] && exit 1

echo "$IMG" > "$STATE_FILE"
swww img "$IMG" --transition-type fade --transition-duration 1

# Signal waybar to update star status
pkill -RTMIN+11 waybar
