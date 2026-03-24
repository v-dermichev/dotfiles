# Instructions

## 1. Requirements
- zsh
- wezterm
- oh-my-zsh
- neovim (using Lazy.nvim for plugins)
- tmux+tpm
- git
- zsh-autoswitch-virtualenv

## 2. One of many ways to replicate setup
```shell
git clone --bare https://github.com/v-dermichev.git $HOME/.dotfiles
alias dotfiles='/usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'
dotfiles checkout
dotfiles config --local status.showUntrackedFiles no
```

## 3. Hyprland + Waybar Setup (Artix/Arch)

### Packages
```shell
# Core
pacman -S hyprland waybar wofi grim slurp swappy mako socat jq

# Screenshot & annotation
pacman -S hyprshot satty
yay -S wayscriber-bin

# Audio
pacman -S pipewire pipewire-pulse wireplumber

# Bluetooth
pacman -S bluez bluez-utils blueman

# Notification sounds
pacman -S libcanberra sound-theme-freedesktop

# System monitor
pacman -S mission-center

# Clipboard
pacman -S wl-clipboard cliphist

# Other
pacman -S brightnessctl nm-applet gnome-keyring
```

### System config (not in dotfiles)

**NVIDIA + Intel hybrid (modprobe)** — `/etc/modprobe.d/nvidia.conf`:
```
options nvidia_drm modeset=1 fbdev=1
```

**GRUB kernel params** — add to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`:
```
nvidia-drm.modeset=1 nvidia_drm.fbdev=1
```
Then run `grub-mkconfig -o /boot/grub/grub.cfg`.

**NVIDIA initramfs modules** — in `/etc/mkinitcpio.conf`:
```
MODULES=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

**NVIDIA runtime PM (AC/battery switch)** — `/etc/udev/rules.d/90-nvidia-power.rules`:
```
SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="/usr/local/bin/nvidia-power-switch.sh"
SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="/usr/local/bin/nvidia-power-switch.sh"
```
With `/usr/local/bin/nvidia-power-switch.sh`:
```bash
#!/bin/bash
NVIDIA_PM="/sys/bus/pci/devices/0000:01:00.0/power/control"
AC_ONLINE="/sys/class/power_supply/ADP1/online"
[ -f "$NVIDIA_PM" ] || exit 0
[ -f "$AC_ONLINE" ] || exit 0
if [ "$(cat "$AC_ONLINE")" = "1" ]; then
    echo "on" > "$NVIDIA_PM"
else
    echo "auto" > "$NVIDIA_PM"
fi
```

**Bluetooth auto-reconnect** — uncomment in `/etc/bluetooth/main.conf` `[Policy]`:
```
AutoEnable=true
ReconnectAttempts=7
ReconnectIntervals=1,2,4,8,16,32,64
```

**Pipewire realtime scheduling** — `/etc/security/limits.d/99-audio.conf`:
```
@audio - rtprio 95
@audio - nice -19
@audio - memlock unlimited
```
Add your user to the `audio` group: `gpasswd -a $USER audio`
