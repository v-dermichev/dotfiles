#!/bin/bash
# Show notification history via wofi

pkill -x wofi && exit 0

makoctl history 2>/dev/null | awk -F': ' '
/^Notification [0-9]+:/ { if (app) print app " — " title; title=$2; app="" }
/^  App name:/ { app=$2 }
END { if (app) print app " — " title }
' | wofi --dmenu --prompt "Notifications"
