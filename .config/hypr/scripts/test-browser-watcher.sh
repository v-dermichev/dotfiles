#!/bin/bash
# Hyprland event listener with two responsibilities:
#   1. Move browser windows spawned by a test runner (pytest, dotnet test,
#      playwright, chromedriver, ...) to `special:tests` as floating windows.
#   2. Hide waybar while the `tests` scratchpad is visible; restore on hide.
#
# Started from the hyprland.start handler in hyprland.lua. Exits if the event
# socket is gone.

set -u

SOCK="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

TEST_RUNNERS='^(python|python[0-9.]+|pytest|py\.test|dotnet|node|npm|npx|playwright|chromedriver|geckodriver|msedgedriver|selenium-server|selenium|robot|behave|mvn|gradle|gradlew|sbt|rspec|cucumber|cypress|karma|jest|vitest|webdriver-mana)$'

BROWSER_CLASSES='^(chromium|chromium-browser|Chromium|Chromium-browser|google-chrome|Google-chrome|Google-chrome-stable|brave-browser|Brave-browser|firefox|Firefox|Navigator|MozillaFirefox|microsoft-edge|Microsoft-edge|microsoft-edge-stable|microsoft-edge-dev)$'

is_test_descendant() {
    local pid="$1" depth=0 comm
    while [[ -n "$pid" && "$pid" -gt 1 && $depth -lt 32 ]]; do
        comm=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ') || return 1
        [[ -z "$comm" ]] && return 1
        [[ "$comm" =~ $TEST_RUNNERS ]] && return 0
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ') || return 1
        depth=$((depth + 1))
    done
    return 1
}

handle_open() {
    local data="$1" addr wclass rest pid
    addr="${data%%,*}"
    addr="${addr#0x}"
    rest="${data#*,}"; rest="${rest#*,}"
    wclass="${rest%%,*}"

    [[ "$wclass" =~ $BROWSER_CLASSES ]] || return

    pid=$(hyprctl clients -j 2>/dev/null \
          | jq -r --arg a "0x$addr" '.[] | select(.address == $a) | .pid' \
          | head -1)
    [[ -z "$pid" || "$pid" == "null" || "$pid" -lt 2 ]] && return

    if is_test_descendant "$pid"; then
        hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:tests\", window = \"address:0x$addr\" })" >/dev/null
        hyprctl dispatch "hl.dsp.window.float({ action = \"toggle\", window = \"address:0x$addr\" })" >/dev/null
    fi
}

waybar_hidden=0
handle_special() {
    local data="$1" ws_name
    ws_name="${data%%,*}"
    if [[ "$ws_name" == "special:tests" ]]; then
        if [[ $waybar_hidden -eq 0 ]]; then
            pkill -USR1 -x waybar && waybar_hidden=1
        fi
    else
        if [[ $waybar_hidden -eq 1 ]]; then
            pkill -USR1 -x waybar && waybar_hidden=0
        fi
    fi
}

[[ -S "$SOCK" ]] || { echo "test-browser-watcher: socket not found at $SOCK" >&2; exit 1; }

while IFS= read -r line; do
    [[ -n "${TBW_DEBUG:-}" ]] && echo "$(date +%H:%M:%S.%N) $line" >> /tmp/test-browser-watcher.log
    case "$line" in
        openwindow\>\>*)     handle_open    "${line#openwindow>>}" ;;
        activespecial\>\>*)  handle_special "${line#activespecial>>}" ;;
    esac
done < <(socat -u "UNIX-CONNECT:$SOCK" -)
