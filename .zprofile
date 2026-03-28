# Added by Toolbox App
export PATH="$PATH:$HOME/.local/share/JetBrains/Toolbox/scripts"

if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    bash ~/.config/hypr/start-audio.sh
    exec dbus-run-session start-hyprland
fi

