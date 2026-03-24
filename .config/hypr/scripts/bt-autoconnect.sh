#!/bin/bash
# Auto-connect trusted bluetooth devices after boot
# Accepts multiple MACs as arguments or space-separated in HYPR_BT_DEVICES

DEVICES="${@:-$HYPR_BT_DEVICES}"
[ -z "$DEVICES" ] && exit 0
MAX_ATTEMPTS=5

# Wait for bluetooth adapter
for i in $(seq 1 10); do
    bluetoothctl show 2>/dev/null | grep -q "Powered: yes" && break
    sleep 1
done

# Attempt connection for each device
for DEV in $DEVICES; do
    for i in $(seq 1 $MAX_ATTEMPTS); do
        if bluetoothctl info "$DEV" 2>/dev/null | grep -q "Connected: yes"; then
            break
        fi
        bluetoothctl connect "$DEV" 2>/dev/null
        sleep 3
    done
done
