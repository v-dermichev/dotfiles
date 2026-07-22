#!/bin/bash
# NuGet API helper for the nvim installer (lua/config/nuget.lua).
# Subcommands: search <query> | preview <id> | versions <id>
set -o pipefail
API=https://azuresearch-usnc.nuget.org/query
FLAT=https://api.nuget.org/v3-flatcontainer
REG=https://api.nuget.org/v3/registration5-gz-semver2
HUM='def h: if .>=1e9 then "\(./1e9*10|floor/10)B" elif .>=1e6 then "\(./1e6*10|floor/10)M" elif .>=1e3 then "\(./1e3*10|floor/10)K" else tostring end;'

low() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

case "$1" in
search)
  q="$2"
  {
    curl -s --get "$API" --data-urlencode "q=$q" --data-urlencode take=40 --data-urlencode prerelease=false |
      jq -r "$HUM"' .data[] | [.id, .version, (.totalDownloads // 0 | h), (if .verified then "✓" else "·" end)] | @tsv'
    # The search index sometimes misses real packages (e.g. MySql.EntityFrameworkCore).
    # If the query looks like an exact id, probe flatcontainer and append it.
    if [[ "$q" =~ ^[A-Za-z0-9_.-]+$ ]]; then
      latest=$(curl -s "$FLAT/$(low "$q")/index.json" |
        jq -r '.versions // [] | map(select(contains("-") | not)) | last // empty' 2>/dev/null)
      [ -n "$latest" ] && printf '%s\t%s\t-\t·\n' "$q" "$latest"
    fi
  } | awk -F'\t' 'tolower($1) in seen { next } { seen[tolower($1)]; print }'
  ;;

preview)
  id="$2"
  reg=$(curl -s --compressed "$REG/$(low "$id")/index.json")
  # newest LISTED release date (unlisted versions carry published=1900-01-01);
  # registration pages either inline their items or point to a page document
  pub=$(echo "$reg" | jq -r '[.items[-1].items[]?.catalogEntry.published | select(.[0:4] != "1900")] | max // empty | .[0:10]' 2>/dev/null)
  [ -z "$pub" ] && pub=$(curl -s --compressed "$(echo "$reg" | jq -r '.items[-1]["@id"]')" 2>/dev/null |
    jq -r '[.items[]?.catalogEntry.published | select(.[0:4] != "1900")] | max // empty | .[0:10]' 2>/dev/null)

  info=$(curl -s --get "$API" --data-urlencode "q=packageid:$id")
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
    curl -s "$FLAT/$(low "$id")/index.json" | jq -r '.versions // [] | reverse | .[0:12][]'
  fi
  ;;

versions)
  id="$2"
  out=$(curl -s --get "$API" --data-urlencode "q=packageid:$id" |
    jq -r "$HUM"' .data[0].versions // [] | reverse | .[] | [.version, (.downloads // 0 | h)] | @tsv' 2>/dev/null)
  if [ -n "$out" ]; then
    echo "$out"
  else
    curl -s "$FLAT/$(low "$id")/index.json" | jq -r '.versions // [] | reverse | .[] | [., "-"] | @tsv'
  fi
  ;;
esac
