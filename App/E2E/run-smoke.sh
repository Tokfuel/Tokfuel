#!/usr/bin/env bash
# IT-F010-LC01: 起動スモーク。デバッグビルドで主要画面へ到達できることを確かめる。
# 使い方: bash App/E2E/run-smoke.sh
#
# Maestro / Appium は使わない。既存の --ui-preview 経路で画面を描画し、
# 期待画面一覧と空画像チェックで到達を担保する（見た目の回帰は VRT / ui-preview レビュー側）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
E2E_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPECTED="$E2E_DIR/expected-screens.txt"
OUT_DIR="${TOKFUEL_E2E_OUT:-$(mktemp -d "${TMPDIR:-/tmp}/tokfuel-e2e.XXXXXX")}"
CLEANUP_OUT=0
if [[ -z "${TOKFUEL_E2E_OUT:-}" ]]; then
  CLEANUP_OUT=1
fi

cleanup() {
  if [[ "$CLEANUP_OUT" -eq 1 ]]; then
    rm -rf "$OUT_DIR"
  fi
}
trap cleanup EXIT

echo "E2E smoke output: $OUT_DIR"
bash "$ROOT/Scripts/ui-preview.sh" "$OUT_DIR"

missing=0
while IFS= read -r line || [[ -n "$line" ]]; do
  name="${line%%#*}"
  name="$(echo "$name" | tr -d '[:space:]')"
  [[ -z "$name" ]] && continue
  png="$OUT_DIR/${name}.png"
  if [[ ! -f "$png" ]]; then
    echo "missing expected screen: $name ($png)" >&2
    missing=1
  fi
done < "$EXPECTED"

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

echo "E2E smoke OK ($(grep -v -E '^[[:space:]]*(#|$)' "$EXPECTED" | wc -l | tr -d ' ') screens)"
