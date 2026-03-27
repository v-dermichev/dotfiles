#!/bin/bash
# Launch wofi as toggle
# Usage: wofi-wrapper.sh <mode> [args]
#   mode: drun, cliphist, dmenu

MODE="$1"
shift

pkill -x wofi && exit 0

case "$MODE" in
    cliphist)
        cliphist list | wofi --dmenu "$@" | cliphist decode | wl-copy
        ;;
    dmenu)
        wofi --dmenu "$@"
        ;;
    *)
        wofi --show "$MODE" "$@"
        ;;
esac
