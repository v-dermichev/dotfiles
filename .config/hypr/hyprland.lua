-- Hyprland Lua config, translated from hyprland.conf (kept as hyprland.conf.pre-lua.bak).
-- Rollback: delete/rename this file and `hyprctl reload` — Hyprland falls back to hyprland.conf.

---------------------------
---- VARIABLES ----
---------------------------

local internal        = "eDP-1"
local external        = "HDMI-A-1"
local internalMode    = "1920x1080@144"
local externalMode    = "1920x1080@120"
local activeOpacity   = 0.92
local inactiveOpacity = 0.87
local screenshotDir   = "~/Screenshots"

---------------------------
---- ENVIRONMENT ----
---------------------------

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("TERMINAL", "kitty")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

hl.env("HYPR_ACTIVE_OPACITY", tostring(activeOpacity))
hl.env("HYPR_INACTIVE_OPACITY", tostring(inactiveOpacity))
hl.env("HYPR_INTERNAL", internal)
hl.env("HYPR_EXTERNAL", external)
hl.env("HYPR_INTERNAL_MODE", internalMode)

---------------------------
---- MONITORS ----
---------------------------

hl.monitor({ output = internal, mode = internalMode, position = "0x0", scale = 1 })
hl.monitor({ output = external, mode = externalMode, position = "1920x0", scale = 1 })

-- Auto-disable internal monitor when external is connected
-- Uses a lid switch handler to persist across DPMS/suspend/hotplug
-- (hyprctl keyword doesn't work under the lua config manager; use hyprctl eval)
local disableInternalCmd = string.format(
    [[hyprctl eval 'hl.monitor({ output = "%s", disabled = true })']], internal)
local enableInternalCmd = string.format(
    [[hyprctl eval 'hl.monitor({ output = "%s", mode = "%s", position = "0x0", scale = 1, disabled = false })']],
    internal, internalMode)
local externalConnectedCmd = string.format(
    [[hyprctl monitors all -j | jq -e --arg n "%s" 'any(.[]; .name == $n)' >/dev/null]], external)

hl.bind("switch:on:Lid Switch",
    hl.dsp.exec_cmd(externalConnectedCmd .. " && " .. disableInternalCmd),
    { locked = true })
hl.bind("switch:off:Lid Switch",
    hl.dsp.exec_cmd(externalConnectedCmd .. " && " .. disableInternalCmd .. " || " .. enableInternalCmd),
    { locked = true })

---------------------------
---- OPTIONS ----
---------------------------

hl.config({
    input = {
        kb_layout     = "us,ru",
        kb_options    = "grp:alt_shift_toggle",
        follow_mouse  = 2,
        accel_profile = "flat",
        sensitivity   = 0.0,
    },

    cursor = {
        no_hardware_cursors = false,
        default_monitor     = external,
    },

    misc = {
        disable_hyprland_logo   = true,
        force_default_wallpaper = 0,
    },

    animations = {
        enabled = true,
    },

    decoration = {
        rounding         = 8,
        active_opacity   = activeOpacity,
        inactive_opacity = inactiveOpacity,
    },

    general = {
        layout                  = "dwindle",
        resize_on_border        = true,
        extend_border_grab_area = 14,
        hover_icon_on_border    = true,
        border_size             = 2,
        gaps_out                = 10,
        col = {
            active_border   = "rgba(8899aacc)",
            inactive_border = "rgba(2b303b88)",
        },
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },
})

---------------------------
---- WORKSPACES ----
---------------------------

hl.workspace_rule({ workspace = "1", monitor = external, default = true })
hl.workspace_rule({ workspace = "2", monitor = external })
hl.workspace_rule({ workspace = "3", monitor = external })
hl.workspace_rule({ workspace = "4", monitor = external })
hl.workspace_rule({ workspace = "5", monitor = external })
hl.workspace_rule({ workspace = "6", monitor = external })
hl.workspace_rule({ workspace = "7", monitor = external })
hl.workspace_rule({ workspace = "8", monitor = external })
hl.workspace_rule({ workspace = "9", monitor = internal, default = true })

-- Named workspaces
hl.workspace_rule({ workspace = "name:IDE", monitor = external })
hl.workspace_rule({ workspace = "name:Steam", monitor = external })
hl.workspace_rule({ workspace = "name:Windows", monitor = external })

-- Scratchpads
hl.workspace_rule({ workspace = "special:music", on_created_empty = "chromium --app=https://music.yandex.ru --profile-directory=Music" })
hl.workspace_rule({ workspace = "special:messenger", on_created_empty = "chromium --app=https://messenger.360.yandex.com/ --profile-directory=Messenger" })
hl.workspace_rule({ workspace = "special:telegram", on_created_empty = "telegram-desktop" })
hl.workspace_rule({ workspace = "special:obsidian", on_created_empty = "obsidian" })
hl.workspace_rule({ workspace = "special:tests" })

---------------------------
---- AUTOSTART ----
---------------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("swaync")
    hl.exec_cmd("waybar")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets --control-directory=/run/user/1000/keyring")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("brave", { workspace = "1" })
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("wayscriber --daemon")
    hl.exec_cmd(externalConnectedCmd .. " && " .. disableInternalCmd)
    hl.exec_cmd("~/.config/hypr/scripts/monitor-watcher.sh")
    hl.exec_cmd("~/.config/hypr/scripts/test-browser-watcher.sh")
    hl.exec_cmd("kitty yazi ~", { workspace = "2" })
end)

---------------------------
---- KEYBINDS ----
---------------------------

local mod = "SUPER"

hl.bind(mod .. " + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle-internal-monitor.sh"))

-- hl.bind(mod .. " + C", hl.dsp.exec_cmd("~/.config/hypr/scripts/wofi-wrapper.sh cliphist"))

hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/wofi-wrapper.sh drun"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + M", hl.dsp.exit())
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exec_cmd("pkill waybar; waybar &"))

-- Scratchpads
hl.bind(mod .. " + Z", hl.dsp.workspace.toggle_special("messenger"))
hl.bind(mod .. " + X", hl.dsp.workspace.toggle_special("music"))
hl.bind(mod .. " + C", hl.dsp.workspace.toggle_special("obsidian"))
hl.bind(mod .. " + V", hl.dsp.workspace.toggle_special("telegram"))
hl.bind(mod .. " + B", hl.dsp.workspace.toggle_special("tests"))

-- Named workspaces
hl.bind(mod .. " + A", hl.dsp.exec_cmd("~/.config/hypr/scripts/workspace-launch.sh IDE neovide"))
hl.bind(mod .. " + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/workspace-launch.sh Steam steam"))
hl.bind(mod .. " + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/workspace-launch.sh Windows virt-manager"))

-- Focus
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Move windows
hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))

-- Floating & layout
hl.bind(mod .. " + SHIFT + Z", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Workspace scroll
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e-1" }))

-- Switch workspace / move window to workspace
for i = 1, 9 do
    hl.bind(mod .. " + " .. i,             hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i,     hl.dsp.window.move({ workspace = i }))
end

-- Task manager
hl.bind("CTRL + SHIFT + escape", hl.dsp.exec_cmd("missioncenter"))

-- Screen annotation
hl.bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd("wayscriber --daemon-toggle"))

-- Screenshots — all save to screenshotDir and copy to clipboard
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region -o " .. screenshotDir .. [[ -f "$(date +'%Y-%m-%d-%H%M%S').png" --raw | tee >(wl-copy) | swappy -f -]]))
hl.bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd("hyprshot -m region -o " .. screenshotDir .. [[ -f "$(date +'%Y-%m-%d-%H%M%S').png"]]))
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("hyprshot -m window -o " .. screenshotDir .. [[ -f "$(date +'%Y-%m-%d-%H%M%S').png"]]))
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("hyprshot -m output -o " .. screenshotDir .. [[ -f "$(date +'%Y-%m-%d-%H%M%S').png"]]))
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m output -o " .. screenshotDir .. [[ -f "$(date +'%Y-%m-%d-%H%M%S').png"]]))

-- Screen recording — toggle start/stop
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/screen-record.sh mp4"))
hl.bind(mod .. " + SHIFT + G", hl.dsp.exec_cmd("~/.config/hypr/scripts/screen-record.sh gif"))

-- Volume
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))

-- Lock
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd("hyprlock"))

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"))

---------------------------
---- WINDOW RULES ----
---------------------------

hl.window_rule({
    name  = "jetbrains-toolbox",
    match = { class = "^(jetbrains-toolbox)$" },
    monitor = external,
    float   = true,
    center  = true,
})

hl.window_rule({
    name  = "satty",
    match = { class = [[^(com\.gabm\.satty)$]] },
    float  = true,
    center = true,
})

hl.window_rule({
    name  = "neovide",
    match = { class = "^(neovide)$" },
    workspace = "name:IDE",
})

hl.window_rule({
    name  = "steam",
    match = { class = "^(steam)$" },
    workspace = "name:Steam",
})
