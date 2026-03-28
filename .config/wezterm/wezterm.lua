local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Font
config.font = wezterm.font_with_fallback({
    { family = "JetBrainsMono Nerd Font", weight = "Regular" },
    "Noto Color Emoji",
})
config.font_size = 10

-- Colors
config.colors = require("cyberdream")
config.force_reverse_video_cursor = true

-- Window
config.initial_rows = 50
config.initial_cols = 200
config.window_decorations = "NONE"
config.window_background_opacity = 0.7
config.window_close_confirmation = "NeverPrompt"
config.front_end = "WebGpu"

-- Cursor
config.cursor_blink_rate = 0

-- Bell — trigger window urgency
config.audible_bell = "Disabled"
config.visual_bell = {
    target = "CursorColor",
    fade_in_duration_ms = 0,
    fade_out_duration_ms = 0,
}

-- Tab Bar
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.show_tab_index_in_tab_bar = false
config.use_fancy_tab_bar = false

local transparent_bg = "rgba(22, 24, 26, 0.8)"
config.colors.tab_bar = {
    background = transparent_bg,
    new_tab = { fg_color = config.colors.background, bg_color = config.colors.brights[6] },
    new_tab_hover = { fg_color = config.colors.background, bg_color = config.colors.foreground },
}

-- Tab Formatting
wezterm.on("format-tab-title", function(tab, _, _, _, hover)
    local background = config.colors.brights[1]
    local foreground = config.colors.foreground

    if tab.is_active then
        background = config.colors.brights[7]
        foreground = config.colors.background
    elseif hover then
        background = config.colors.brights[8]
        foreground = config.colors.background
    end

    local title = tostring(tab.tab_index + 1)
    return {
        { Foreground = { Color = background } },
        { Text = "█" },
        { Background = { Color = background } },
        { Foreground = { Color = foreground } },
        { Text = title },
        { Foreground = { Color = background } },
        { Text = "█" },
    }
end)

-- Keybindings
config.keys = {
    { key = "/", mods = "CTRL", action = wezterm.action.SendString("\x1f") },
    { key = "Enter", mods = "ALT", action = wezterm.action.DisableDefaultAssignment },
}

-- Shell
config.default_prog = { "zsh" }

return config
