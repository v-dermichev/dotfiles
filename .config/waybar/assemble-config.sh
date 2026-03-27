#!/bin/bash
# Assemble waybar config.jsonc from template + generated fragments

WAYBAR_DIR="$HOME/.config/waybar"
TEMPLATE="$WAYBAR_DIR/config.template.jsonc"
OUTPUT="$WAYBAR_DIR/config.jsonc"

[ -f "$TEMPLATE" ] || exit 1

# Read module lists
WS_MODULES=$(cat "$WAYBAR_DIR/workspace-modules.json" 2>/dev/null || echo "")
SP_MODULES=$(cat "$WAYBAR_DIR/scratchpad-modules.json" 2>/dev/null || echo "")

# Build ignore-workspaces list
WS_NAMES=""
CONF="$HOME/.config/hypr/workspaces.conf"
if [ -f "$CONF" ]; then
    while IFS='|' read -r name rest; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        [ -n "$WS_NAMES" ] && WS_NAMES+=", "
        WS_NAMES+="\"$name\""
    done < "$CONF"
fi

# Add trailing commas
[ -n "$WS_MODULES" ] && WS_MODULES="$WS_MODULES,"
[ -n "$SP_MODULES" ] && SP_MODULES="$SP_MODULES,"

# Phase 1: replace inline placeholders
sed \
    -e "s|{{WORKSPACE_MODULES}}|$WS_MODULES|" \
    -e "s|{{SCRATCHPAD_MODULES}}|$SP_MODULES|" \
    -e "s|{{WORKSPACE_NAMES}}|$WS_NAMES|" \
    "$TEMPLATE" > "$OUTPUT.tmp"

# Phase 2: replace multi-line block placeholders with file contents
python3 -c "
import sys
with open('$OUTPUT.tmp') as f:
    content = f.read()
for placeholder, path in [
    ('{{WORKSPACE_DEFS}}', '$WAYBAR_DIR/workspace-defs.json'),
    ('{{SCRATCHPAD_DEFS}}', '$WAYBAR_DIR/scratchpad-defs.json'),
]:
    try:
        with open(path) as pf:
            # Indent each line by 4 spaces
            replacement = pf.read().rstrip()
            lines = replacement.split('\n')
            indented = '\n'.join('    ' + line if line.strip() else line for line in lines)
            content = content.replace(placeholder, indented)
    except FileNotFoundError:
        content = content.replace(placeholder, '')
with open('$OUTPUT', 'w') as f:
    f.write(content)
"

rm -f "$OUTPUT.tmp"
