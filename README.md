# Dotfiles

![Showcase](showcase.png)

Hyprland + Waybar setup with transparent windows, nerd font icons, smart monitor management, and a unified dark theme across all components.

All hardware-specific values (monitor names, resolutions, opacity, bluetooth devices) are configurable via variables at the top of `hyprland.conf` — no need to hunt through the config.

# Instructions

## 1. Requirements
- zsh
- kitty or wezterm (terminal)
- oh-my-zsh
- neovim (using Lazy.nvim for plugins)
- tmux+tpm
- git
- zsh-autoswitch-virtualenv

## 2. One of many ways to replicate setup
```shell
git clone --bare https://github.com/v-dermichev/dotfiles.git $HOME/.dotfiles
alias dotfiles='/usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'
dotfiles checkout
dotfiles config --local status.showUntrackedFiles no
```

## 3. Hyprland + Waybar Setup (Artix/Arch)

> **Note:** This setup is systemd-free. All services use OpenRC, elogind, udev rules, and shell scripts instead of systemd units/timers.
>
> **Privacy:** systemd merged a `birthDate` field into its userdb records ([PR #40954](https://github.com/systemd/systemd/pull/40954)) for age verification compliance. elogind is unaffected — it only handles login sessions and power management, and does not include systemd's userdb/homectl components where the DOB field lives.

### Packages
```shell
# Core
pacman -S hyprland waybar wofi grim slurp swappy mako socat jq qt6-wayland

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

# Fonts
pacman -S ttf-jetbrains-mono-nerd noto-fonts-emoji


# NVIDIA (skip if not using NVIDIA)
pacman -S nvidia-open-dkms nvidia-utils

# Wallpaper
pacman -S swww
# Build from source: https://github.com/v-dermichev/swww-wproulette
git clone https://github.com/v-dermichev/swww-wproulette && cd swww-wproulette
cargo build --release && sudo cp target/release/wproulette /usr/local/bin/

# Audio control
pacman -S pavucontrol

# Session & power
pacman -S elogind dbus

# Terminal (kitty is default in hyprland.conf)
pacman -S kitty

# Other
pacman -S brightnessctl network-manager-applet gnome-keyring
```

> **Hardware-specific:** Edit variables at the top of `hyprland.conf` to match your hardware:
> - `$internal` / `$external` — monitor names (run `hyprctl monitors` to find yours)
> - `$internalMode` / `$externalMode` — resolutions and refresh rates
> - `$btDevices` — bluetooth MAC address(es), space-separated
> - `$screenshotDir` — where screenshots and recordings are saved
> - `$activeOpacity` / `$inactiveOpacity` — window transparency levels

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

### Scratchpads & Named Workspaces

All workspaces use waybar's native `hyprland/workspaces` module — no custom modules or generators needed.

- **Scratchpads** — toggle-overlay apps defined in `hyprland.conf` with `workspace = special:name, on-created-empty:command`
- **Named workspaces** — dedicated app workspaces (IDE, Steam) with `workspace-launch.sh` for launch-on-first-visit
- **Icons** — configured via waybar's `format-icons` mapping workspace names to nerd font glyphs
- **Notifications** — apps like Telegram set the WM urgent hint natively, waybar highlights with `.urgent` CSS class (blue tint)

### Wallpaper Roulette

Powered by [wproulette](https://github.com/v-dermichev/swww-wproulette) — a Rust CLI for swww with waybar integration.

Waybar includes 4 wallpaper controls (left to right):

1. **Random** (shuffle+image icon) — pick a random wallpaper, excluding trashed
2. **Trash** (bin icon) — trash current and pick a new one. Grayed out when starred
3. **Star** (star icon) — toggle star on current. Dimmed when unstarred, golden when starred
4. **Starred Random** (shuffle+star icon) — pick random from starred favorites only

Workflow: spam random to browse, trash the bad, star the good, then use starred random to enjoy favorites.

Trashed wallpapers preserve subdirectory structure with content hash dedup and can be restored to their original location via `wproulette restore`.

Config and state in `~/.config/wproulette/` — wallpaper directory, transition style, badge glyph.

### Notes

- `.zprofile` starts pipewire before Hyprland so all apps have audio immediately
- The `--systemd` flag in `dbus-update-activation-environment` is misleadingly named — it just exports env vars to the D-Bus activation environment, works with elogind, no systemd required
- NVIDIA runtime PM script paths (`0000:01:00.0`, `ADP1`) are hardware-specific — adjust for your system
- Arch `extra` repo is disabled by default to avoid pulling systemd dependencies. Use `pacman-arch` alias when you need Arch packages. `artix-archlinux-support` provides virtual `systemd`/`systemd-libs` packages for compatibility

### Common Problems

**JetBrains IDEs flickering/artifacts** — Switch to native Wayland rendering by adding `-Dawt.toolkit.name=WLToolkit` to the IDE's `vmoptions` file (Help → Edit Custom VM Options). XWayland causes focus-stealing and rendering issues with Hyprland.

**Thunar can't mount drives** — Install `polkit-gnome` and add to autostart: `exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1`

**Thunar "Unable to find terminal"** — Install `xdg-terminal-exec` (`yay -S xdg-terminal-exec`) and create `~/.config/xdg-terminals.list` with your terminal name (e.g. `kitty`).

**Chromium won't start** — Stale `SingletonLock` file from a crash. Remove `~/.config/chromium/SingletonLock`.

**No notification sounds** — Add `on-notify=exec canberra-gtk-play -i complete` to mako config. Toggle sound mute via waybar bell icon (`makoctl mode -t silent`). DND mode suppresses both sound and visual notifications (`makoctl mode -t do-not-disturb`).

**Clicking notification doesn't focus app** — Add per-app criteria in mako config to switch workspaces on click:
```ini
[app-name="Telegram Desktop"]
on-button-left=exec hyprctl dispatch togglespecialworkspace telegram; makoctl dismiss -n "$id"

[body~="messenger.360.yandex.com"]
on-button-left=exec hyprctl dispatch togglespecialworkspace messenger; makoctl dismiss -n "$id"
```
Use `app-name` for apps with unique names, `body~` or `summary~` (regex) for web app notifications that share the same browser app name.

**Bluetooth headset won't auto-connect at boot** — The included `bt-autoconnect.sh` handles this. Set `$btDevices` in `hyprland.conf` to your device MAC(s). Sony/similar headsets need the host to initiate — BlueZ `AutoEnable` alone isn't enough.

**Brave password autofill not working** — Known bug in Brave 1.88.x/Chromium 146 on Wayland ([#50882](https://github.com/brave/brave-browser/issues/50882)). Fix: add `--enable-features=UseOzonePlatform` and `--ozone-platform=x11` to `~/.config/brave-flags.conf`.

**Cursor disappearing/flickering on NVIDIA** — Set `no_hardware_cursors = true` in `hyprland.conf` cursor section. Hardware cursors work on newer NVIDIA drivers (590+) but may cause issues on older versions or multi-monitor setups.

**Internal monitor keeps re-enabling** — `hyprctl keyword monitor` is a runtime override that doesn't survive DPMS/suspend cycles. The included `monitor-watcher.sh` listens to Hyprland events and re-enforces the disable.
