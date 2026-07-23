#!/usr/bin/env bash
# Claude Code PostToolUse hook (Edit|Write): after a file is modified, ping
# every running nvim instance so a buffer holding that file reloads
# (config.autosave.external_change -> :checktime with autoread).
f=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty')
[ -n "$f" ] || exit 0
# vimscript single-quoted string: '' is the escape for a literal quote
fq=$(printf %s "$f" | sed "s/'/''/g")
for s in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/nvim.*.0; do
  [ -S "$s" ] || continue
  # timeout: --remote-expr blocks if nvim is stuck on a prompt
  timeout 2 nvim --server "$s" --remote-expr \
    "v:lua.require'config.autosave'.external_change('$fq')" >/dev/null 2>&1
done
exit 0
