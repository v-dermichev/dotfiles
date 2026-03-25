#!/bin/bash
# Monitor D-Bus notifications and count per app
# Writes counts to /tmp/notif-count-<app>

COUNT_DIR="/tmp/notif-counts"
mkdir -p "$COUNT_DIR"

dbus-monitor "interface='org.freedesktop.Notifications',member='Notify'" 2>/dev/null | while read -r line; do
    if [[ "$line" == *"member=Notify"* ]]; then
        # Next string line is the app name
        read -r appline
        if [[ "$appline" == *"string \""* ]]; then
            APP=$(echo "$appline" | sed 's/.*string "//;s/".*//')
            case "$APP" in
                "Telegram Desktop"|"telegram"*|"org.telegram"*)
                    FILE="$COUNT_DIR/telegram"
                    COUNT=$(cat "$FILE" 2>/dev/null || echo 0)
                    echo $((COUNT + 1)) > "$FILE"
                    pkill -RTMIN+12 waybar
                    ;;
                "Brave"*|"brave"*|"Chromium"*|"chromium"*)
                    FILE="$COUNT_DIR/messenger"
                    COUNT=$(cat "$FILE" 2>/dev/null || echo 0)
                    echo $((COUNT + 1)) > "$FILE"
                    pkill -RTMIN+12 waybar
                    ;;
            esac
        fi
    fi
done
