#!/bin/bash
# Auto-generated notification counter
COUNT_DIR="/tmp/notif-counts"
mkdir -p "$COUNT_DIR"

dbus-monitor "interface='org.freedesktop.Notifications',member='Notify'" 2>/dev/null | while read -r line; do
    if [[ "$line" == *"member=Notify"* ]]; then
        read -r appline
        if [[ "$appline" == *"string \""* ]]; then
            APP=$(echo "$appline" | sed 's/.*string "//;s/".*//')
            case "$APP" in
                "Brave"*|"Chromium"*)
                    FILE="$COUNT_DIR/messenger"
                    COUNT=$(cat "$FILE" 2>/dev/null || echo 0)
                    echo $((COUNT + 1)) > "$FILE"
                    pkill -RTMIN+13 waybar
                    ;;
                "Telegram Desktop"*|"org.telegram"*)
                    FILE="$COUNT_DIR/telegram"
                    COUNT=$(cat "$FILE" 2>/dev/null || echo 0)
                    echo $((COUNT + 1)) > "$FILE"
                    pkill -RTMIN+13 waybar
                    ;;
            esac
        fi
    fi
done
