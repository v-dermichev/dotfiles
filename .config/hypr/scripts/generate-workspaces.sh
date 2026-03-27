#!/bin/bash
# Generate named workspace configs from workspaces.conf

CONF="${1:-$HOME/.config/hypr/workspaces.conf}"
HYPR_OUT="$HOME/.config/hypr/workspaces-generated.conf"
WAYBAR_DIR="$HOME/.config/waybar"

[ -f "$CONF" ] || exit 1

# --- Hyprland config (bash is fine for this) ---
{
    echo "# Auto-generated from workspaces.conf — do not edit manually"
    echo ""
    echo "# Workspace definitions"
    while IFS='|' read -r name key cmd icon class_pattern fullscreen; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        echo "workspace = name:$name, monitor:\$external"
    done < "$CONF"
    echo ""
    echo "# Keybinds"
    while IFS='|' read -r name key cmd icon class_pattern fullscreen; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        echo "bind = \$mod, $key, exec, ~/.config/hypr/scripts/workspace-launch.sh $name $cmd"
    done < "$CONF"
    echo ""
    echo "# Window rules"
    while IFS='|' read -r name key cmd icon class_pattern fullscreen; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        echo "windowrule {"
        echo "    name = workspace-$name"
        echo "    match:class = ^(${class_pattern})$"
        echo "    workspace = name:$name"
        [ "$fullscreen" = "true" ] && echo "    fullscreen = 1"
        echo "}"
        echo ""
    done < "$CONF"
} > "$HYPR_OUT"

# --- Waybar (use Python for proper JSON escaping) ---
python3 << 'PYEOF'
import json, os

conf_path = os.path.expanduser(os.environ.get("CONF", "~/.config/hypr/workspaces.conf"))
waybar_dir = os.path.expanduser("~/.config/waybar")

entries = []
with open(conf_path) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) >= 5:
            entries.append({
                "name": parts[0],
                "key": parts[1],
                "cmd": parts[2],
                "icon": parts[3],
                "class_pattern": parts[4],
                "fullscreen": parts[5].strip() if len(parts) > 5 else "false",
            })

# Module list
modules = [f'"custom/workspace-{e["name"].lower()}"' for e in entries]
with open(os.path.join(waybar_dir, "workspace-modules.json"), "w") as f:
    f.write(",".join(modules))

# Module definitions
defs = []
for e in entries:
    lower = e["name"].lower()
    key_upper = e["key"].upper()
    name = e["name"]
    icon = e["icon"]
    cmd = e["cmd"]

    exec_cmd = (
        f'if [ \\"$(hyprctl activeworkspace -j | jq -r \'.name\')\\" = \\"{name}\\" ]; then '
        f'echo \'{{\\\"text\\\": \\\"{icon}\\\", \\\"tooltip\\\": \\\"{name} (active)\\\", \\\"class\\\": \\\"active\\\"}}\'; '
        f'else echo \'{{\\\"text\\\": \\\"{icon}\\\", \\\"tooltip\\\": \\\"{name} (Super+{key_upper})\\\", \\\"class\\\": \\\"inactive\\\"}}\'; fi'
    )

    defs.append(
        f'"custom/workspace-{lower}": {{\n'
        f'    "exec": "{exec_cmd}",\n'
        f'    "return-type": "json",\n'
        f'    "interval": "once",\n'
        f'    "signal": 13,\n'
        f'    "on-click": "~/.config/hypr/scripts/workspace-launch.sh {name} {cmd}"\n'
        f'}},'
    )

with open(os.path.join(waybar_dir, "workspace-defs.json"), "w") as f:
    f.write("\n".join(defs))

# CSS
selectors = [f"#custom-workspace-{e['name'].lower()}" for e in entries]
sel = ",\n".join(selectors)
css = f"/* Auto-generated workspace styles */\n"
css += f"{sel} {{ padding: 0 8px; }}\n\n"
css += f"{','.join(s + '.active' for s in selectors)} {{\n"
css += f"    background-color: #64727D;\n    box-shadow: inset 0 -3px #ffffff;\n}}\n\n"
css += f"{','.join(s + ':hover' for s in selectors)} {{\n"
css += f"    background: rgba(0, 0, 0, 0.2);\n    box-shadow: inset 0 -3px #ffffff;\n}}\n"

with open(os.path.join(waybar_dir, "workspace-style.css"), "w") as f:
    f.write(css)
PYEOF

echo "Generated workspace configs"
