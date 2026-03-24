#!/bin/bash
# Start pipewire audio stack and wait for it to be ready
# Called from .zprofile before Hyprland

RUNTIME_DIR="/run/user/$(id -u)"

# Kill any leftover instances
killall pipewire wireplumber pipewire-pulse 2>/dev/null
sleep 0.2

# Start in correct order: pipewire -> pipewire-pulse -> wireplumber
pipewire &
for _ in $(seq 1 50); do
    [ -S "$RUNTIME_DIR/pipewire-0" ] && break
    sleep 0.1
done

pipewire-pulse &
for _ in $(seq 1 50); do
    [ -S "$RUNTIME_DIR/pulse/native" ] && break
    sleep 0.1
done

wireplumber &
for _ in $(seq 1 50); do
    wpctl status &>/dev/null && break
    sleep 0.1
done
