#!/bin/bash
# Play a sound on every desktop notification
# Listens to D-Bus Notifications interface
# State controlled via /tmp/notification-sound-enabled

STATE_FILE="/tmp/notification-sound-enabled"
[ -f "$STATE_FILE" ] || echo "1" > "$STATE_FILE"

LAST_PLAY=0

dbus-monitor "interface='org.freedesktop.Notifications',member='Notify'" 2>/dev/null | while read -r line; do
    if [[ "$line" == *"member=Notify"* ]]; then
        if [ "$(cat "$STATE_FILE")" = "1" ]; then
            NOW=$(date +%s)
            if (( NOW - LAST_PLAY >= 1 )); then
                LAST_PLAY=$NOW
                canberra-gtk-play -i message-new-instant 2>/dev/null &
            fi
        fi
    fi
done
