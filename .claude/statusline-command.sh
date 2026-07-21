#!/bin/sh
# Claude Code status line — agnoster-inspired
input=$(cat)

# Single jq pass over stdin; @sh-quoted so eval is safe
eval "$(echo "$input" | jq -r '@sh "cwd=\(.workspace.current_dir // .cwd // "")
model=\(.model.display_name // "")
used=\(.context_window.used_percentage // "")
five_h=\(.rate_limits.five_hour.used_percentage // "")
five_h_reset=\(.rate_limits.five_hour.resets_at // "")
seven_d=\(.rate_limits.seven_day.used_percentage // "")
seven_d_reset=\(.rate_limits.seven_day.resets_at // "")"')"

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch (skip optional locks)
git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)

# Build left side

# Directory segment
left=$(printf '\033[34m%s\033[0m' "$short_cwd")

# Git branch segment
if [ -n "$git_branch" ]; then
    left=$(printf '%s \033[33m(%s)\033[0m' "$left" "$git_branch")
fi

# Model + effort segment
effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)
if [ -n "$model" ]; then
    if [ -n "$effort" ]; then
        left=$(printf '%s \033[36m[%s·%s]\033[0m' "$left" "$model" "$effort")
    else
        left=$(printf '%s \033[36m[%s]\033[0m' "$left" "$model")
    fi
fi

# Context usage segment
if [ -n "$used" ]; then
    left=$(printf '%s \033[35mctx:%s%%\033[0m' "$left" "$(printf '%.0f' "$used")")
fi

# Rate limit segments
now=$(date +%s)

fmt_remaining() {
    secs=$(($1 - now))
    if [ "$secs" -le 0 ]; then printf 'now'; return; fi
    h=$((secs / 3600))
    m=$(((secs % 3600) / 60))
    if [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"
    else printf '%dm' "$m"; fi
}

limits=""
if [ -n "$five_h" ]; then
    reset_str=""
    if [ -n "$five_h_reset" ]; then reset_str=" -> $(fmt_remaining "$five_h_reset")"; fi
    limits=$(printf '\033[33m5h:%s%%%s\033[0m' "$(printf '%.0f' "$five_h")" "$reset_str")
fi
if [ -n "$seven_d" ]; then
    reset_str=""
    if [ -n "$seven_d_reset" ]; then reset_str=" -> $(fmt_remaining "$seven_d_reset")"; fi
    entry=$(printf '\033[31m7d:%s%%%s\033[0m' "$(printf '%.0f' "$seven_d")" "$reset_str")
    if [ -n "$limits" ]; then
        limits=$(printf '%s %s' "$limits" "$entry")
    else
        limits="$entry"
    fi
fi

if [ -n "$limits" ]; then
    printf '%s \033[90m│\033[0m %s\n' "$left" "$limits"
else
    printf '%s\n' "$left"
fi
