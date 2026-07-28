#!/bin/bash
# Lint the roadmaps/ tree: every TF item directory must hold a matching EN file and JA mirror,
# each with a TF-METADATA block and a valid Status (状態). Mirrors bajutsu's lint-roadmap idea,
# scaled down to a hand-maintained index (no generated tables to check).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
err() { echo "roadmap-lint: $1" >&2; fail=1; }

VALID_STATUS='Proposal|In progress|Implemented|Deferred'
VALID_STATUS_JA='提案|進行中|実装済み|保留'

shopt -s nullglob
dirs=(roadmaps/TF-*/)
[ ${#dirs[@]} -gt 0 ] || { err "no TF item directories found under roadmaps/"; exit 1; }

seen_ids=""
for dir in "${dirs[@]}"; do
  name="$(basename "$dir")"                       # TF-NNNN-<slug>
  id="${name%%-"${name#TF-????-}"}"               # TF-NNNN
  en="$dir$name.md"
  ja="$dir$name-ja.md"

  # Directory name shape
  [[ "$name" =~ ^TF-[0-9]{4}-[a-z0-9-]+$ ]] || err "$name: directory name must be TF-NNNN-<kebab-slug>"

  # Unique IDs
  case " $seen_ids " in *" $id "*) err "$id: duplicate ID";; esac
  seen_ids="$seen_ids $id"

  # Both language files exist and match the directory name
  [ -f "$en" ] || { err "$name: missing English file $name.md"; continue; }
  [ -f "$ja" ] || { err "$name: missing Japanese mirror $name-ja.md"; continue; }

  # Metadata block + Status in the English file
  grep -q '<!-- TF-METADATA -->' "$en" || err "$name: EN file lacks <!-- TF-METADATA --> block"
  grep -Eq "^\| Status \| \*\*($VALID_STATUS)\*\* \|" "$en" \
    || err "$name: EN file lacks a valid '| Status | **<value>** |' row ($VALID_STATUS)"

  # Metadata block + 状態 in the Japanese file
  grep -q '<!-- TF-METADATA -->' "$ja" || err "$name: JA file lacks <!-- TF-METADATA --> block"
  grep -Eq "^\| 状態 \| \*\*($VALID_STATUS_JA)\*\* \|" "$ja" \
    || err "$name: JA file lacks a valid '| 状態 | **<値>** |' row ($VALID_STATUS_JA)"

  # Bilingual cross-links in the headers
  grep -q "$name-ja.md" "$en" || err "$name: EN file does not link its Japanese mirror"
  grep -q "$name.md" "$ja"    || err "$name: JA file does not link its English original"

  # Every item appears in both index READMEs
  grep -q "$name" roadmaps/README.md    || err "$name: not listed in roadmaps/README.md"
  grep -q "$name" roadmaps/README-ja.md || err "$name: not listed in roadmaps/README-ja.md"
done

# Index rows must not point at items that don't exist
# (strip the -ja file suffix the Japanese index links carry)
for readme in roadmaps/README.md roadmaps/README-ja.md; do
  while IFS= read -r ref; do
    ref="${ref%-ja}"
    [ -d "roadmaps/$ref" ] || err "$readme references missing item $ref"
  done < <(grep -oE 'TF-[0-9]{4}-[a-z0-9-]+' "$readme" | sort -u)
done

if [ "$fail" -ne 0 ]; then
  echo "roadmap-lint: FAILED" >&2
  exit 1
fi
echo "roadmap-lint: OK (${#dirs[@]} items)"
