#!/bin/bash
# Launchers are layer surfaces rather than windows, so the window-close
# dispatcher reaches straight past them to the window underneath. Close a live
# launcher first and only fall through to the focused window when none is up.

pkill -x rofi && exit 0
pkill -x wofi && exit 0

hyprctl dispatch 'hl.dsp.window.close()'
