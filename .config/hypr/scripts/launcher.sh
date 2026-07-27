#!/bin/bash
# Application launcher (rofi).
#   Enter        launch normally, so window rules place the app
#   Shift+Enter  launch on the focused workspace, overriding those rules
#
# rofi exits 10 for kb-custom-1. Entries round-trip by index rather than by
# display name, so the exec line is never re-derived from what was shown.

set -u

pkill -x rofi && exit 0

HISTORY="${XDG_STATE_HOME:-$HOME/.local/state}/launcher-history"
INDEX=$(mktemp) || exit 1
trap 'rm -f "$INDEX"' EXIT

list_entries() {
    python3 - "$INDEX" "$HISTORY" <<'PY'
import os, sys, glob, time, configparser

index_path, history_path = sys.argv[1], sys.argv[2]

# count halves every 14 days, so a burst of old launches loses to steady recent use
history, now = {}, time.time()
try:
    with open(history_path) as fh:
        for line in fh:
            count, last, name = line.rstrip("\n").split("\t", 2)
            age_days = max(0.0, (now - float(last)) / 86400)
            history[name] = int(count) * (0.5 ** (age_days / 14))
except (OSError, ValueError):
    pass

seen, rows = set(), []
dirs = [os.path.expanduser("~/.local/share/applications")]
dirs += [os.path.join(d, "applications")
         for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")]

for d in dirs:
    for path in sorted(glob.glob(os.path.join(d, "**", "*.desktop"), recursive=True)):
        key = os.path.relpath(path, d)
        if key in seen:
            continue
        seen.add(key)
        cp = configparser.RawConfigParser(interpolation=None, strict=False)
        try:
            cp.read(path, encoding="utf-8")
            entry = cp["Desktop Entry"]
        except Exception:
            continue
        if entry.get("Type") != "Application" \
                or entry.getboolean("NoDisplay", fallback=False) \
                or entry.getboolean("Hidden", fallback=False):
            continue
        name, exec_line = entry.get("Name"), entry.get("Exec")
        if not name or not exec_line:
            continue
        rows.append((name, exec_line,
                     entry.getboolean("Terminal", fallback=False),
                     entry.get("Icon", "")))

rows.sort(key=lambda r: (-history.get(r[0], 0.0), r[0].lower()))

index = open(index_path, "w")
for name, exec_line, terminal, icon in rows:
    index.write("%s\t%d\t%s\n" % (exec_line, terminal, name))
    sys.stdout.write("%s\0icon\x1f%s\n" % (name, icon))
index.close()
PY
}

record_launch() {
    python3 - "$HISTORY" "$1" <<'PY'
import os, sys, time, tempfile

history_path, chosen = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(history_path), exist_ok=True)

entries = {}
try:
    with open(history_path) as fh:
        for line in fh:
            count, last, name = line.rstrip("\n").split("\t", 2)
            entries[name] = (int(count), float(last))
except (OSError, ValueError):
    pass

count = entries.get(chosen, (0, 0))[0] + 1
entries[chosen] = (count, time.time())

fd, tmp = tempfile.mkstemp(dir=os.path.dirname(history_path))
with os.fdopen(fd, "w") as out:
    for name, (count, last) in entries.items():
        out.write("%d\t%f\t%s\n" % (count, last, name))
os.replace(tmp, history_path)
PY
}

current_workspace() {
    local name
    name=$(hyprctl activeworkspace -j | jq -r '.name')
    case "$name" in
        special:*) printf '%s' "$name" ;;
        '' | *[!0-9]*) printf 'name:%s' "$name" ;;
        *) printf '%s' "$name" ;;
    esac
}

# Shift+Return ships bound to kb-accept-alt; rofi refuses a duplicate binding
# and shows an error screen instead of the list, so free it first.
row=$(list_entries | rofi -dmenu -i -show-icons -format d \
    -kb-accept-alt "" -kb-custom-1 "Shift+Return")
code=$?

[ -n "$row" ] || exit 0

IFS=$'\t' read -r exec_line terminal name < <(sed -n "${row}p" "$INDEX")

# Field codes stand in for files/URIs opened with the app; nothing supplies
# them here and they are not valid argv.
exec_line=$(printf '%s' "$exec_line" | sed -E 's/ ?%[fFuUdDnNickvm]//g')

[ "$terminal" = "1" ] && exec_line="${TERMINAL:-kitty} -e $exec_line"

record_launch "$name"

if [ "$code" -eq 10 ]; then
    hyprctl dispatch "hl.dsp.exec_cmd([[$exec_line]], { workspace = \"$(current_workspace)\" })"
else
    hyprctl dispatch "hl.dsp.exec_cmd([[$exec_line]])"
fi
