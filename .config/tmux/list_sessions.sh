#!/usr/bin/env bash

current_session=$(tmux display -p '#S')

sessions=$(tmux list-sessions 2>/dev/null | awk '{print $1}')

output=""
for s in $sessions; do
    # Remove trailing colon
    s=${s%:}
    if [[ "$s" == "$current_session" ]]; then
        # Highlight current session
        output+="#[fg=#0f0f1a,bg=#ff61a6,bold]  $s #[fg=#ff61a6,bg=#0f0f1a] #[default]"
    else
        output+="#[fg=#7f7fff]  $s #[default]"
    fi
done

echo "$output"

