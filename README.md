# Dotfiles

![Showcase](showcase.png)

Hyprland + Waybar setup with transparent windows, nerd font icons, smart monitor management, and a unified dark theme across all components.

All hardware-specific values (monitor names, resolutions, opacity) are configurable via locals at the top of `hyprland.lua` — no need to hunt through the config. (Hyprland ≥ 0.55 uses the Lua config manager; `hyprland.conf` is kept as a legacy fallback for older versions.)

## Quick Start

```shell
curl -fsSL https://raw.githubusercontent.com/v-dermichev/dotfiles/master/bootstrap.sh | sh
```

This clones the bare repo, backs up any conflicting files, and checks out all configs. Then:

```shell
source ~/.zshrc
dotfiles --healthcheck   # see what's missing
dotfiles --install       # install missing packages
```

## Manual Setup

```shell
git clone --bare https://github.com/v-dermichev/dotfiles.git $HOME/.dotfiles
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME checkout
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME config --local status.showUntrackedFiles no
source ~/.zshrc
```

## Dotfiles CLI

After setup, the `dotfiles` command provides both custom subcommands and full git passthrough:

```
dotfiles --healthcheck   Check all dependencies and configs
dotfiles --install       Install missing dependencies (pacman + manual)
dotfiles --sync          Pull latest dotfiles from remote
dotfiles --backup        Snapshot tracked configs to ~/.dotfiles-backup/
dotfiles --edit          Open .zshrc in $EDITOR
dotfiles --help          Show usage

dotfiles status          Git passthrough
dotfiles add / commit / push / log / diff / ...
```

## Dependencies

### Checked by `dotfiles --healthcheck`

| Dependency | Install |
|---|---|
| oh-my-zsh | `sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"` |
| zsh-autosuggestions | `git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions` |
| zsh-syntax-highlighting | `git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting` |
| git | `sudo pacman -S git` |
| fzf | `sudo pacman -S fzf` |
| zoxide | `sudo pacman -S zoxide` |
| yazi | `sudo pacman -S yazi` |
| tmux | `sudo pacman -S tmux` |
| kitty | `sudo pacman -S kitty` |
| neovim | `sudo pacman -S neovim` |
| dotnet | `sudo pacman -S dotnet-sdk` |
| nvm | `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh \| bash` |

## Hyprland + Waybar Setup (Artix/Arch)

> **Note:** This setup is systemd-free. All services use OpenRC, elogind, udev rules, and shell scripts instead of systemd units/timers.
>
> **Privacy:** systemd merged a `birthDate` field into its userdb records ([PR #40954](https://github.com/systemd/systemd/pull/40954)) for age verification compliance. elogind is unaffected — it only handles login sessions and power management, and does not include systemd's userdb/homectl components where the DOB field lives.

### Packages
```shell
# Core
pacman -S hyprland waybar wofi grim slurp swappy swaync socat jq qt6-wayland

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
pacman -S awww
# Build from source: https://github.com/v-dermichev/awww-wproulette
git clone https://github.com/v-dermichev/awww-wproulette && cd awww-wproulette
cargo build --release && sudo cp target/release/wproulette /usr/local/bin/

# Audio control
pacman -S pavucontrol

# Session & power
pacman -S elogind dbus

# Terminal (kitty is default in hyprland.lua)
pacman -S kitty

# Other
pacman -S brightnessctl network-manager-applet gnome-keyring
```

> **Hardware-specific:** Edit the locals at the top of `hyprland.lua` to match your hardware:
> - `internal` / `external` — monitor names (run `hyprctl monitors` to find yours)
> - `internalMode` / `externalMode` — resolutions and refresh rates
> - `screenshotDir` — where screenshots and recordings are saved
> - `activeOpacity` / `inactiveOpacity` — window transparency levels

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

- **Scratchpads** — toggle-overlay apps defined in `hyprland.lua` with `hl.workspace_rule({ workspace = "special:name", on_created_empty = "command" })`
- **Pin every scratchpad app with a window rule** — `on_created_empty` only *launches* the command. The window it eventually maps goes to whichever workspace is focused at map time, so without a matching `hl.window_rule({ ..., workspace = "special:name silent" })` a slow-starting app lands on a neighbouring scratchpad, and an app that opens windows unprompted (an incoming Telegram call) can spawn one over a fullscreen game. Chromium `--app` windows take the class `chrome-<host>__-<profile-directory>`
- **Named workspaces** — dedicated app workspaces (IDE, Steam) with `workspace-launch.sh`, which relaunches the app when *it* has no window on the workspace; unrelated windows sharing that workspace are ignored
- **Icons** — configured via waybar's `format-icons` mapping workspace names to nerd font glyphs. Values are literal strings, so a `"default": "{name}"` fallback renders that placeholder verbatim — give every workspace you use its own entry
- **Notifications** — apps like Telegram set the WM urgent hint natively, waybar highlights with `.urgent` CSS class (blue tint)

### Monitors & Persisted State

Numbered workspaces are split across the two displays: **1–9 on the external**, **10–19 on the internal panel**. `SUPER + <digit>` reaches the first bank, `SUPER + ALT + <digit>` the second (with `0` standing in for 10); add `SHIFT` to move the focused window instead. `SUPER + P` toggles the internal panel.

Runtime toggles write their choice under `~/.local/state/hypr/` and `hyprland.lua` reads it back at load, so `hyprctl reload` restates the current setup instead of reverting to the declared defaults:

| File | Written by | Read by |
|---|---|---|
| `internal-monitor` | `toggle-internal-monitor.sh` (`toggle`/`on`/`off`/`auto`) | monitor declaration |
| `transparency` | `toggleTransparency()` in `hyprland.lua` | `decoration` opacity |

Two properties of the Lua config manager shape this:

- **`hyprctl` cannot be called from config context.** Config code runs on the compositor thread, so an inner `hyprctl` call waits for a reply that cannot be sent until it returns, and times out. Anything the config needs to know about hardware must come from elsewhere — the monitor connection check reads `/sys/class/drm/*-<output>/status`.
- **The Lua VM persists between evals.** A global function defined at config load stays callable, so the Waybar transparency button is a single `hyprctl eval 'toggleTransparency()'` rather than a read-modify-write through `hyprctl getoption` and `jq`. Note that `hyprctl eval` prints `ok` and discards return values, so status readouts still have to read the state file directly.

The internal panel is disabled only while the external display is attached; with nothing else connected it always comes back on, so no reload or hotplug can leave the machine without output.

### Wallpaper Roulette

Powered by [wproulette](https://github.com/v-dermichev/awww-wproulette) — a Rust CLI for awww with waybar integration.

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

**No notification sounds** — Using swaync with a script in `config.json`: `"exec": "canberra-gtk-play -i complete"` with `"run-on": "receive"`. DND toggle via waybar bell icon (right-click) or notification center panel.

**Clicking notification doesn't focus app** — Add per-app scripts in swaync `config.json`:
```json
"telegram-focus": {
    "exec": "hyprctl dispatch togglespecialworkspace telegram",
    "app-name": "Telegram Desktop",
    "run-on": "action"
}
```
Use `app-name` for apps with unique names, `body` (regex) for web app notifications that share the same browser app name.

**Bluetooth headset won't auto-connect at boot** — Make sure `AutoEnable=true` is set in `/etc/bluetooth/main.conf` and the device is trusted (`bluetoothctl trust <MAC>`). Trusted devices reconnect on their own when powered on.

**Brave password autofill not working** — Known bug in Brave 1.88.x/Chromium 146 on Wayland ([#50882](https://github.com/brave/brave-browser/issues/50882)). Fix: add `--enable-features=UseOzonePlatform` and `--ozone-platform=x11` to `~/.config/brave-flags.conf`.

**Cursor disappearing/flickering on NVIDIA** — Set `no_hardware_cursors = true` in the `hyprland.lua` cursor section. Hardware cursors work on newer NVIDIA drivers (590+) but may cause issues on older versions or multi-monitor setups.

**Internal monitor keeps re-enabling** — a runtime disable (`hyprctl eval 'hl.monitor({ output = ..., disabled = true })'`) is only an override; any config reload re-declares the monitor and undoes it. The fix is to make the config agree with the choice rather than to detect and correct it afterwards: `toggle-internal-monitor.sh` records the state in `~/.local/state/hypr/internal-monitor`, and `hyprland.lua` reads it back on every load. Hotplug is handled in-config by `hl.on("monitor.added")` / `hl.on("monitor.removed")`, so no watcher process is involved. Note that re-enabling needs an explicit `disabled = false` — the flag is sticky.

**Steam/Proton games crash on launch or stutter under shader compile (UE5, large titles)** — Modern engines open thousands of shader/PSO files in parallel during precompile. The default `nofile` ulimit (often 4096 on a fresh Artix install) gets exhausted and the game dies with a generic `EXCEPTION_ACCESS_VIOLATION` whose real cause only shows up in `~/steam-<appid>.log` after setting `PROTON_LOG=1` — look for `err:winediag:NtCreateFile Too many open files`. Fix via PAM (`pam_limits.so` is already in `system-auth`, no systemd needed) — create `/etc/security/limits.d/99-nofile.conf`:
```
*       soft    nofile    524288
*       hard    nofile    1048576
root    soft    nofile    524288
root    hard    nofile    1048576
```
Then fully log out and back in (limits are set at PAM session creation, not refreshed mid-session). Verify with `ulimit -Hn` — should print `1048576`, not `4096`.
