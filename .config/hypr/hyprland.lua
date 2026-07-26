-- Hyprland config for the Lua config manager (Hyprland >= 0.55). There is no
-- hyprland.conf counterpart: the state files read back at load need Lua's file
-- I/O, which the legacy format cannot express.
-- Hardware-specific values are the locals directly below.

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
---- PERSISTED STATE ----
---------------------------

-- Runtime toggles (Super+P, the Waybar transparency button) write their choice
-- into this directory, and every config load reads it back. That is what makes
-- the config agree with the last explicit choice, so `hyprctl reload` restates
-- it instead of reverting to a default that something else has to correct.
local stateDir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/hypr"

local function stateValue(name)
    local f = io.open(stateDir .. "/" .. name, "r")
    if not f then return nil end
    local v = f:read("*l")
    f:close()
    return v
end

local function writeState(name, value)
    local path = stateDir .. "/" .. name
    local f = io.open(path, "w")
    if not f then
        io.popen("mkdir -p '" .. stateDir .. "'"):close()
        f = io.open(path, "w")
        if not f then return false end
    end
    f:write(value .. "\n")
    f:close()
    return true
end

-- Global on purpose: the manager's Lua VM persists between evals, so a function
-- defined at config load stays callable for the rest of the session. That lets
-- the Waybar button drive this with a single `hyprctl eval 'toggleTransparency()'`
-- instead of shelling out to read the current opacity and then set it.
-- Accepts "on" / "off", or nothing to flip whatever is stored.
function toggleTransparency(action)
    local target = action
    if target ~= "on" and target ~= "off" then
        target = stateValue("transparency") == "off" and "on" or "off"
    end

    writeState("transparency", target)

    if target == "off" then
        hl.config({ decoration = { active_opacity = 1.0, inactive_opacity = 1.0 } })
    else
        hl.config({ decoration = { active_opacity = activeOpacity, inactive_opacity = inactiveOpacity } })
    end
end

---------------------------
---- MONITORS ----
---------------------------

local function internalPreference()
    local v = stateValue("internal-monitor")
    if v == "enabled" or v == "disabled" then return v end
    return nil
end

-- Physical connection read straight from DRM. Hyprland's IPC cannot be queried
-- from inside the config: config code runs on the compositor thread, so an inner
-- `hyprctl` call waits on a reply that cannot be sent until it returns. sysfs is
-- the only monitor source available in this context.
local function drmConnected(output)
    local p = io.popen("cat /sys/class/drm/*-" .. output .. "/status 2>/dev/null")
    if not p then return false end
    local out = p:read("*a") or ""
    p:close()
    for line in out:gmatch("[^\r\n]+") do
        if line == "connected" then return true end
    end
    return false
end

-- An explicit "enabled" keeps the panel on even alongside the external display.
-- Anything else -- "disabled", or no stored choice yet -- means the panel is off
-- exactly while the external is attached. Both paths leave it on when nothing
-- else is connected, so no branch here can leave the machine without output.
local function applyInternal()
    local disabled = internalPreference() ~= "enabled" and drmConnected(external)
    if disabled then
        hl.monitor({ output = internal, disabled = true })
    else
        hl.monitor({ output = internal, mode = internalMode, position = "0x0", scale = 1, disabled = false })
    end
end

applyInternal()
hl.monitor({ output = external, mode = externalMode, position = "1920x0", scale = 1 })

-- swaync binds its notification layer to an output at startup; when the output
-- set changes it can be left rendering popups on a screen that is gone while the
-- center silently keeps collecting them. Restart it to rebind.
local function rebindSwaync()
    hl.exec_cmd("pkill -x swaync; setsid -f swaync >/dev/null 2>&1")
end

hl.on("monitor.added", function()
    applyInternal()
    rebindSwaync()
end)

hl.on("monitor.removed", function()
    applyInternal()
    rebindSwaync()
end)

-- Lid transitions route through the same script as Super+P so every state change
-- has one writer; `auto` follows whether the external display is attached.
hl.bind("switch:on:Lid Switch",
    hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle-internal-monitor.sh auto"),
    { locked = true })
hl.bind("switch:off:Lid Switch",
    hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle-internal-monitor.sh auto"),
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

    -- Fully opaque only when transparency has been switched off; any other value,
    -- including no stored choice yet, uses the blended defaults above.
    decoration = {
        rounding         = 8,
        active_opacity   = stateValue("transparency") == "off" and 1.0 or activeOpacity,
        inactive_opacity = stateValue("transparency") == "off" and 1.0 or inactiveOpacity,
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

-- 1-9 belong to the external display, 10-19 to the internal panel. The lowest of
-- each range is that monitor's default, so it is the one shown when the monitor
-- appears with no workspace of its own yet.
local function assignWorkspaces(first, last, monitor)
    for i = first, last do
        local rule = { workspace = tostring(i), monitor = monitor }
        if i == first then rule.default = true end
        hl.workspace_rule(rule)
    end
end

assignWorkspaces(1, 9, external)
assignWorkspaces(10, 19, internal)

-- Named workspaces
hl.workspace_rule({ workspace = "name:IDE", monitor = external })
hl.workspace_rule({ workspace = "name:Steam", monitor = external })
hl.workspace_rule({ workspace = "name:Windows", monitor = external })

-- Scratchpads
hl.workspace_rule({ workspace = "special:music", on_created_empty = "chromium --app=https://music.yandex.ru --profile-directory=Music" })
hl.workspace_rule({ workspace = "special:messenger", on_created_empty = "chromium --app=https://messenger.360.yandex.com/ --profile-directory=Messenger" })
hl.workspace_rule({ workspace = "special:telegram", on_created_empty = "telegram-desktop" })
hl.workspace_rule({ workspace = "special:discord", on_created_empty = "discord" })
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
hl.bind(mod .. " + N", hl.dsp.workspace.toggle_special("discord"))

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

-- ALT shifts the same number row onto the internal panel's 10-19 bank, with 0
-- standing in for 10 so the digits stay in their natural left-to-right order.
for i = 0, 9 do
    local ws = (i == 0) and 10 or (10 + i)
    hl.bind(mod .. " + ALT + " .. i,           hl.dsp.focus({ workspace = ws }))
    hl.bind(mod .. " + SHIFT + ALT + " .. i,   hl.dsp.window.move({ workspace = ws }))
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

-- virt-manager connects to libvirt before mapping anything, so it is slow enough
-- that focus has usually moved on by the time its window appears.
hl.window_rule({
    name  = "virt-manager",
    match = { class = "^(virt-manager)$" },
    workspace = "name:Windows",
})

-- Steam games (any steam_app_* window): fullscreen on workspace 8,
-- exempt from opacity blending and blur
hl.window_rule({
    name  = "steam-games",
    match = { class = [[^(steam_app_\d+)$]] },
    workspace = "8",
    fullscreen = true,
    opacity    = 1.0,
    no_blur    = true,
})

-- Telegram: every toplevel (main window, detached chats, incoming-call popups)
-- belongs on the telegram scratchpad. `silent` places it there without pulling
-- the view along, so a call arriving mid-game cannot spawn a window over a
-- fullscreen client and knock it out of fullscreen.
hl.window_rule({
    name  = "telegram",
    match = { class = [[^(org\.telegram\.desktop)$]] },
    workspace = "special:telegram silent",
})

hl.window_rule({
    name  = "discord",
    match = { class = "^(discord)$" },
    workspace = "special:discord silent",
})

-- Remaining scratchpad apps. `on_created_empty` only launches the app; placement
-- of the window it eventually maps is decided by whichever workspace is focused
-- at map time. Pinning each class makes that deterministic, so toggling between
-- scratchpads while one is still starting cannot land its window on a neighbour.
-- Chromium derives an --app window's class as chrome-<host>__-<profile-directory>.
hl.window_rule({
    name  = "obsidian",
    match = { class = "^(obsidian)$" },
    workspace = "special:obsidian silent",
})

hl.window_rule({
    name  = "music",
    match = { class = [[^(chrome-music\.yandex\.ru.*)$]] },
    workspace = "special:music silent",
})

hl.window_rule({
    name  = "messenger",
    match = { class = [[^(chrome-messenger\.360\.yandex\.com.*)$]] },
    workspace = "special:messenger silent",
})
