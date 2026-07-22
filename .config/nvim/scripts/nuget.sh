#!/bin/bash
# NuGet API helper for the nvim installer (lua/config/nuget.lua).
# Subcommands: search <query> | preview <id> | versions <id>
#
# Caching: every GET goes through cached_get — inside the TTL the response is
# served from disk with no network; after the TTL it revalidates with the
# stored ETag (flatcontainer/registration send them; 304 keeps the cache, a
# metadata change refetches). On network failure the stale copy is served.
set -o pipefail
API=https://azuresearch-usnc.nuget.org/query
FLAT=https://api.nuget.org/v3-flatcontainer
REG=https://api.nuget.org/v3/registration5-gz-semver2
HUM='def h: if .>=1e9 then "\(./1e9*10|floor/10)B" elif .>=1e6 then "\(./1e6*10|floor/10)M" elif .>=1e3 then "\(./1e3*10|floor/10)K" else tostring end;'

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nvim-nuget"
TTL_META="${NUGET_CACHE_TTL:-600}"   # package metadata: ETag-revalidated after this
TTL_SEARCH=120                       # search queries: no ETags upstream, plain TTL

low() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

urlenc() { jq -rn --arg s "$1" '$s|@uri'; }

# cached_get <ttl> <url> — body on stdout
cached_get() {
  local ttl="$1" url="$2"
  mkdir -p "$CACHE"
  local key body etag tmp age=999999
  key=$(echo -n "$url" | sha256sum | cut -c1-32)
  body="$CACHE/$key.body" etag="$CACHE/$key.etag" tmp="$CACHE/$key.tmp.$$"

  [ -f "$body" ] && age=$(( $(date +%s) - $(stat -c %Y "$body") ))
  if [ "$age" -lt "$ttl" ]; then cat "$body"; return 0; fi

  local args=(-s --compressed --max-time 10 -o "$tmp" --etag-save "$etag.new")
  [ -s "$etag" ] && args+=(--etag-compare "$etag")
  if curl "${args[@]}" "$url"; then
    if [ -s "$tmp" ]; then
      mv -f "$tmp" "$body"                       # fresh data (200)
      [ -s "$etag.new" ] && mv -f "$etag.new" "$etag" || rm -f "$etag.new"
    else
      rm -f "$tmp" "$etag.new"                   # 304 — cache still valid
      touch "$body" 2>/dev/null
    fi
  else
    rm -f "$tmp" "$etag.new"                     # offline/error — serve stale
  fi
  cat "$body" 2>/dev/null
}

gc() { # drop entries untouched for a week; at most once a day
  local mark="$CACHE/.gc"
  [ -f "$mark" ] && [ $(( $(date +%s) - $(stat -c %Y "$mark") )) -lt 86400 ] && return
  mkdir -p "$CACHE"; touch "$mark"
  find "$CACHE" -type f -mtime +7 -delete 2>/dev/null &
}
gc

case "$1" in
search)
  q="$2"
  {
    cached_get "$TTL_SEARCH" "$API?q=$(urlenc "$q")&take=40&prerelease=false" |
      jq -r "$HUM"' .data[] | [.id, .version, (.totalDownloads // 0 | h), (if .verified then "✓" else "·" end)] | @tsv'
    # The search index sometimes misses real packages (e.g. MySql.EntityFrameworkCore).
    # If the query looks like an exact id, probe flatcontainer and append it.
    if [[ "$q" =~ ^[A-Za-z0-9_.-]+$ ]]; then
      latest=$(cached_get "$TTL_META" "$FLAT/$(low "$q")/index.json" |
        jq -r '.versions // [] | map(select(contains("-") | not)) | last // empty' 2>/dev/null)
      [ -n "$latest" ] && printf '%s\t%s\t-\t·\n' "$q" "$latest"
    fi
  } | awk -F'\t' 'tolower($1) in seen { next } { seen[tolower($1)]; print }'
  ;;

preview)
  id="$2"
  reg=$(cached_get "$TTL_META" "$REG/$(low "$id")/index.json")
  # newest LISTED release date (unlisted versions carry published=1900-01-01);
  # registration pages either inline their items or point to a page document
  pub=$(echo "$reg" | jq -r '[.items[-1].items[]?.catalogEntry.published | select(.[0:4] != "1900")] | max // empty | .[0:10]' 2>/dev/null)
  if [ -z "$pub" ]; then
    page=$(echo "$reg" | jq -r '.items[-1]["@id"] // empty' 2>/dev/null)
    [ -n "$page" ] && pub=$(cached_get "$TTL_META" "$page" |
      jq -r '[.items[]?.catalogEntry.published | select(.[0:4] != "1900")] | max // empty | .[0:10]' 2>/dev/null)
  fi

  info=$(cached_get "$TTL_META" "$API?q=packageid:$(urlenc "$id")")
  if [ "$(echo "$info" | jq -r '.data | length' 2>/dev/null)" != "0" ]; then
    echo "$info" | jq -r "$HUM"' .data[0]
      | "\(.id)  \(if .verified then "✓ verified" else "" end)\n"
      + "latest:    \(.version)\n"
      + "updated:   '"${pub:--}"'\n"
      + "downloads: \(.totalDownloads // 0 | h)  (total)\n"
      + "owners:    \(.owners // [] | join(", "))\n"
      + "project:   \(.projectUrl // "-")\n"
      + "tags:      \(.tags // [] | join(", ") | if . == "" then "-" else . end)\n\n"
      + "\(.description // "")\n\n"
      + "── recent versions ──\n"
      + ([.versions[] | {v: .version, d: .downloads}] | reverse | .[0:12]
         | map("\(.v)  (\(.d // 0 | h))") | join("\n"))'
  else
    echo "$id  (absent from the NuGet search index)"
    echo "updated:   ${pub:--}"
    echo
    echo "── versions ──"
    cached_get "$TTL_META" "$FLAT/$(low "$id")/index.json" | jq -r '.versions // [] | reverse | .[0:12][]'
  fi
  ;;

versions)
  id="$2"
  out=$(cached_get "$TTL_META" "$API?q=packageid:$(urlenc "$id")" |
    jq -r "$HUM"' .data[0].versions // [] | reverse | .[] | [.version, (.downloads // 0 | h)] | @tsv' 2>/dev/null)
  if [ -n "$out" ]; then
    echo "$out"
  else
    cached_get "$TTL_META" "$FLAT/$(low "$id")/index.json" | jq -r '.versions // [] | reverse | .[] | [., "-"] | @tsv'
  fi
  ;;
esac
