#!/usr/bin/env bash
# Regenerates the contributor avatar row in README.md / README.ja.md from the
# commit history on main. Idempotent: leaves the files untouched if the
# rendered block hasn't changed. See issue #35 for the design.
set -euo pipefail

repo="${GITHUB_REPOSITORY:-Tokfuel/Tokfuel}"
pinned_login="${PINNED_LOGIN:-akidon0000}"

# login|avatar_url|commit_date, bots and unlinked authors (no GitHub account)
# dropped.
rows="$(gh api --paginate "repos/${repo}/commits?sha=main&per_page=100" \
  | jq -r '.[] | select(.author != null) | select(.author.type != "Bot")
      | [.author.login, .author.avatar_url, .commit.author.date] | join("|")')"

# One row per login — earliest commit date, that row's avatar — sorted by
# date ascending. A single awk pass avoids re-scanning $rows per login.
sorted="$(printf '%s\n' "$rows" | awk -F'|' '
  { login = $1; date = $3
    if (!(login in first) || date < first[login]) { first[login] = date; avatar[login] = $2 } }
  END { for (l in first) print first[l] "|" l "|" avatar[l] }
' | sort)"

pinned_row="$(printf '%s\n' "$sorted" | awk -F'|' -v l="$pinned_login" '$2 == l { print; exit }')"
rest_rows="$(printf '%s\n' "$sorted" | awk -F'|' -v l="$pinned_login" '$2 != l')"
ordered="$pinned_row"$'\n'"$rest_rows"

block="<table><tr>"
while IFS='|' read -r _date login avatar; do
  [[ -z "$login" ]] && continue
  block+="<td align=\"center\"><a href=\"https://github.com/${login}\"><img src=\"${avatar}&s=60\" width=\"60px;\" alt=\"${login}\"/><br /><sub><b>${login}</b></sub></a></td>"
done <<< "$ordered"
block+="</tr></table>"

replace_block() {
  local file="$1"
  awk -v block="$block" '
    /<!-- contributors:start -->/ { print; print block; skip=1; next }
    /<!-- contributors:end -->/ { skip=0; print; next }
    skip == 1 { next }
    { print }
  ' "$file" > "${file}.tmp"
  mv "${file}.tmp" "$file"
}

replace_block README.md
replace_block README.ja.md
