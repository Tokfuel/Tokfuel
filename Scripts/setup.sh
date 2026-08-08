#!/usr/bin/env bash
# Local developer setup (git hooks, etc.). Idempotent.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR=".githooks"

cd "$PROJECT_DIR"

if [[ ! -d "$HOOKS_DIR" ]]; then
  echo "error: $HOOKS_DIR/ not found" >&2
  exit 1
fi

git config core.hooksPath "$HOOKS_DIR"
chmod +x "$HOOKS_DIR"/*

current="$(git config --get core.hooksPath)"
echo "core.hooksPath=$current"
echo "hooks:"
for hook in "$HOOKS_DIR"/*; do
  [[ -f "$hook" ]] || continue
  echo "  $(basename "$hook")"
done
echo "Done."
