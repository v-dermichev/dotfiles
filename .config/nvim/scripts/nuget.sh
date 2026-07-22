#!/bin/bash
# NuGet live-search line feed for nvim's installer (lua/config/nuget.lua).
# Only the search subcommand lives here — fzf's live contents must be a
# spawnable command; preview/versions/caching are in-process lua.
set -o pipefail
API=https://azuresearch-usnc.nuget.org/query
FLAT=https://api.nuget.org/v3-flatcontainer
HUM='def h: if .>=1e9 then "\(./1e9*10|floor/10)B" elif .>=1e6 then "\(./1e6*10|floor/10)M" elif .>=1e3 then "\(./1e3*10|floor/10)K" else tostring end;'

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nvim-nuget"
TTL=120

low() { echo "$1" | tr '[:upper:]' '[:lower:]'; }
urlenc() { jq -rn --arg s "$1" '$s|@uri'; }

# short-TTL disk cache: absorbs backspacing/retyping the same query
cached_get() {
  local url="$1" key body age=999999
  mkdir -p "$CACHE"
  key=$(echo -n "$url" | sha256sum | cut -c1-32)
  body="$CACHE/$key.search"
  [ -f "$body" ] && age=$(( $(date +%s) - $(stat -c %Y "$body") ))
  if [ "$age" -ge "$TTL" ]; then
    curl -s --compressed --max-time 10 -o "$body.tmp.$$" "$url" && mv -f "$body.tmp.$$" "$body" || rm -f "$body.tmp.$$"
  fi
  cat "$body" 2>/dev/null
  find "$CACHE" -name "*.search" -mmin +60 -delete 2>/dev/null
}

[ "$1" = "search" ] || exit 1
q="$2"
{
  cached_get "$API?q=$(urlenc "$q")&take=40&prerelease=false" |
    jq -r "$HUM"' .data[] | [.id, .version, (.totalDownloads // 0 | h), (if .verified then "✓" else "·" end)] | @tsv'
  # The search index sometimes misses real packages (e.g. MySql.EntityFrameworkCore).
  # If the query looks like an exact id, probe flatcontainer and append it.
  if [[ "$q" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    latest=$(cached_get "$FLAT/$(low "$q")/index.json" |
      jq -r '.versions // [] | map(select(contains("-") | not)) | last // empty' 2>/dev/null)
    [ -n "$latest" ] && printf '%s\t%s\t-\t·\n' "$q" "$latest"
  fi
} | awk -F'\t' -v q="$(low "$q")" '
  # dedupe by id (search rows first, so their download counts win) and float
  # an exact-id match to the top — fzf runs disabled in live mode, so display
  # order is feed order
  tolower($1) in seen { next }
  { seen[tolower($1)] }
  tolower($1) == q { exact = $0; next }
  { rows[++n] = $0 }
  END {
    if (exact != "") print exact
    for (i = 1; i <= n; i++) print rows[i]
  }'
