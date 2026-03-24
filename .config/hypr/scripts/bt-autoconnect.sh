#!/bin/bash
# Auto-connect trusted bluetooth audio devices after boot
# Waits for bluetooth adapter to be powered, then attempts connection

DEVICE="${HYPR_BT_DEVICE:-${1:-}}"
[ -z "$DEVICE" ] && exit 0
MAX_ATTEMPTS=5

# Wait for bluetooth adapter
for i in $(seq 1 10); do
    bluetoothctl show 2>/dev/null | grep -q "Powered: yes" && break
    sleep 1
done

# Attempt connection
for i in $(seq 1 $MAX_ATTEMPTS); do
    if bluetoothctl info "$DEVICE" 2>/dev/null | grep -q "Connected: yes"; then
        exit 0
    fi
    bluetoothctl connect "$DEVICE" 2>/dev/null
    sleep 3
done
