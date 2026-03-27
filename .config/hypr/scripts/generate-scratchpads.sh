#!/bin/bash
# Generate scratchpad configs from scratchpads.conf

CONF="${1:-$HOME/.config/hypr/scratchpads.conf}"
HYPR_OUT="$HOME/.config/hypr/scratchpads-generated.conf"
WAYBAR_DIR="$HOME/.config/waybar"
THEME="$HOME/.config/hypr/theme.conf"

# Read badge from theme.conf
BADGE="●"
[ -f "$THEME" ] && BADGE=$(grep "^badge=" "$THEME" | cut -d= -f2)

[ -f "$CONF" ] || exit 1

# --- Hyprland config ---
{
    echo "# Auto-generated from scratchpads.conf — do not edit manually"
    echo ""
    echo "# Workspace definitions"
    while IFS='|' read -r name key cmd icon color notify_match; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        echo "workspace = special:$name, on-created-empty:$cmd"
    done < "$CONF"
    echo ""
    echo "# Keybinds"
    while IFS='|' read -r name key cmd icon color notify_match; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        notify_match=$(echo "$notify_match" | tr -d ' ')
        if [ -z "$notify_match" ]; then
            echo "bind = \$mod, $key, togglespecialworkspace, $name"
        else
            echo "bind = \$mod, $key, exec, echo 0 > /tmp/notif-counts/$name; hyprctl dispatch togglespecialworkspace $name; pkill -RTMIN+13 waybar"
        fi
    done < "$CONF"
} > "$HYPR_OUT"

# --- Waybar (Python for JSON) ---
BADGE="$BADGE" python3 << 'PYEOF'
import os

conf_path = os.path.expanduser(os.environ.get("CONF", "~/.config/hypr/scratchpads.conf"))
waybar_dir = os.path.expanduser("~/.config/waybar")
badge = os.environ.get("BADGE", "●")

entries = []
with open(conf_path) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) >= 4:
            notify_match = parts[5].strip() if len(parts) > 5 and parts[5].strip() else ""
            entries.append({
                "name": parts[0],
                "key": parts[1],
                "cmd": parts[2],
                "icon": parts[3],
                "color": parts[4].strip() if len(parts) > 4 and parts[4].strip() else None,
                "notify": bool(notify_match),
            })

# Module list
modules = [f'"custom/scratchpad-{e["name"]}"' for e in entries]
with open(os.path.join(waybar_dir, "scratchpad-modules.json"), "w") as f:
    f.write(",".join(modules))

# Module definitions
defs = []
for e in entries:
    name = e["name"]
    key_upper = e["key"].upper()
    icon = e["icon"]
    cap_name = name.capitalize()

    if e["notify"]:
        exec_cmd = (
            "C=$(cat /tmp/notif-counts/" + name + " 2>/dev/null || echo 0); "
            "ACTIVE='inactive'; "
            "hyprctl monitors -j | jq -e '.[].specialWorkspace.name' -r 2>/dev/null | grep -q 'special:" + name + "' && ACTIVE='active'; "
            'if [ \\"$C\\" -gt 0 ] && [ \\"$ACTIVE\\" = \'inactive\' ]; then '
            "echo '{\\\"text\\\": \\\"" + icon + " " + badge + "\\\", \\\"tooltip\\\": \\\"" + cap_name + " (new)\\\", \\\"class\\\": \\\"has-notif\\\"}'; "
            "else echo '{\\\"text\\\": \\\"" + icon + "\\\", \\\"tooltip\\\": \\\"" + cap_name + " (Super+" + key_upper + ")\\\", \\\"class\\\": \\\"'$ACTIVE'\\\"}'; fi"
        )
        on_click = "echo 0 > /tmp/notif-counts/" + name + "; hyprctl dispatch togglespecialworkspace " + name + "; pkill -RTMIN+13 waybar"
    else:
        exec_cmd = (
            "if hyprctl monitors -j | jq -e '.[].specialWorkspace.name' -r 2>/dev/null | grep -q 'special:" + name + "'; then "
            "echo '{\\\"text\\\": \\\"" + icon + "\\\", \\\"tooltip\\\": \\\"" + cap_name + " (active)\\\", \\\"class\\\": \\\"active\\\"}'; "
            "else echo '{\\\"text\\\": \\\"" + icon + "\\\", \\\"tooltip\\\": \\\"" + cap_name + " (Super+" + key_upper + ")\\\", \\\"class\\\": \\\"inactive\\\"}'; fi"
        )
        on_click = "hyprctl dispatch togglespecialworkspace " + name + "; pkill -RTMIN+13 waybar"

    defs.append(
        f'"custom/scratchpad-{name}": {{\n'
        f'    "exec": "{exec_cmd}",\n'
        f'    "return-type": "json",\n'
        f'    "interval": "once",\n'
        f'    "signal": 13,\n'
        f'    "on-click": "{on_click}"\n'
        f'}},'
    )

with open(os.path.join(waybar_dir, "scratchpad-defs.json"), "w") as f:
    f.write("\n".join(defs))

# CSS
selectors = [f"#custom-scratchpad-{e['name']}" for e in entries]
sel_join = ",\n".join(selectors)

css = "/* Auto-generated scratchpad styles */\n"
css += f"{sel_join} {{ padding: 0 8px; }}\n\n"
css += f"{','.join(s + '.active' for s in selectors)} {{\n"
css += f"    background-color: #64727D;\n    box-shadow: inset 0 -3px #ffffff;\n}}\n\n"
css += f"{','.join(s + ':hover' for s in selectors)} {{\n"
css += f"    background: rgba(0, 0, 0, 0.2);\n    box-shadow: inset 0 -3px #ffffff;\n}}\n\n"

# Per-scratchpad colors
for e in entries:
    if e["color"]:
        css += f'#custom-scratchpad-{e["name"]} {{ color: {e["color"]}; }}\n'
    # Brighter color for has-notif
    if e["notify"] and e["color"]:
        css += f'#custom-scratchpad-{e["name"]}.has-notif {{ color: {e["color"]}; filter: brightness(1.3); }}\n'

# Group margins
if entries:
    css += f'\n#custom-scratchpad-{entries[0]["name"]} {{ margin-left: 8px; }}\n'
    css += f'#custom-scratchpad-{entries[-1]["name"]} {{ margin-right: 8px; }}\n'

with open(os.path.join(waybar_dir, "scratchpad-style.css"), "w") as f:
    f.write(css)
PYEOF

# --- Notification counter script ---
{
    echo '#!/bin/bash'
    echo '# Auto-generated notification counter'
    echo 'COUNT_DIR="/tmp/notif-counts"'
    echo 'mkdir -p "$COUNT_DIR"'
    echo ''
    echo 'dbus-monitor "interface='"'"'org.freedesktop.Notifications'"'"',member='"'"'Notify'"'"'" 2>/dev/null | while read -r line; do'
    echo '    if [[ "$line" == *"member=Notify"* ]]; then'
    echo '        read -r appline'
    echo '        if [[ "$appline" == *"string \""* ]]; then'
    echo '            APP=$(echo "$appline" | sed '"'"'s/.*string "//;s/".*//'"'"')'
    echo '            case "$APP" in'

    while IFS='|' read -r name key cmd icon color notify_match; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        notify_match=$(echo "$notify_match" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$notify_match" ] && continue

        # Build case pattern from comma-separated prefixes
        PATTERN=""
        IFS=',' read -ra PREFIXES <<< "$notify_match"
        for p in "${PREFIXES[@]}"; do
            p=$(echo "$p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -n "$PATTERN" ] && PATTERN+="|"
            PATTERN+="\"${p}\"*"
        done

        echo "                $PATTERN)"
        echo "                    FILE=\"\$COUNT_DIR/$name\""
        echo '                    COUNT=$(cat "$FILE" 2>/dev/null || echo 0)'
        echo '                    echo $((COUNT + 1)) > "$FILE"'
        echo '                    pkill -RTMIN+13 waybar'
        echo '                    ;;'
    done < "$CONF"

    echo '            esac'
    echo '        fi'
    echo '    fi'
    echo 'done'
} > "$HOME/.config/hypr/scripts/notification-counter.sh"
chmod +x "$HOME/.config/hypr/scripts/notification-counter.sh"

echo "Generated scratchpad configs"
