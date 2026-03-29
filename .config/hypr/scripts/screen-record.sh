#!/bin/bash
# Toggle screen region recording
# If recording, stop and convert. If not, start recording.
# Usage: screen-record.sh [gif|mp4]

FORMAT="${1:-mp4}"
PID_FILE="/tmp/screen-record-pid"
OUTPUT_DIR="$HOME/Screenshots"
mkdir -p "$OUTPUT_DIR"

PID=$(cat "$PID_FILE" 2>/dev/null)
if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    # Stop recording
    kill -INT "$PID"
    rm "$PID_FILE"
    notify-send -a "Screen Record" "Recording" "Saved to $OUTPUT_DIR"

    # Convert to gif if requested
    LAST=$(ls -t "$OUTPUT_DIR"/recording-*.mp4 2>/dev/null | head -1)
    if [ "$FORMAT" = "gif" ] && [ -f "$LAST" ]; then
        GIF="${LAST%.mp4}.gif"
        ffmpeg -i "$LAST" -vf "fps=15,scale=640:-1:flags=lanczos" -c:v gif "$GIF" -y 2>/dev/null &
        notify-send -a "Screen Record" "Recording" "Converting to GIF..."
    fi
else
    # Select region and start recording
    REGION=$(slurp 2>/dev/null)
    [ -z "$REGION" ] && exit 1

    FILENAME="$OUTPUT_DIR/recording-$(date +'%Y-%m-%d-%H%M%S').mp4"
    wf-recorder -g "$REGION" -f "$FILENAME" &
    echo $! > "$PID_FILE"
    notify-send -a "Screen Record" "Recording" "Started (press again to stop)"
fi
