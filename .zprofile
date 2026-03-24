if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    bash ~/.config/hypr/start-audio.sh
    exec dbus-run-session start-hyprland
fi


# Added by Toolbox App
export PATH="$PATH:/home/work/.local/share/JetBrains/Toolbox/scripts"

