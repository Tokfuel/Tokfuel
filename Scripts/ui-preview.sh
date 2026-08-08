#!/bin/bash
# PR の ui-preview 📸 ラベル用に、メニューバー・設定・About の全画面を実物の UI から
# 1 ディレクトリへ書き出す（TF-0034）。使い方: bash Scripts/ui-preview.sh [出力先ディレクトリ]
#
# 絵の中身（フィクスチャ・撮る画面の一覧）は App/TokfuelUI/ScreenshotRenderer.swift が持つ。
# README 用の Scripts/screenshot.sh と同じく -AppleAccentColor 1 でアクセントカラーを固定し、
# --ui-preview も #if DEBUG のため debug ビルドのバイナリで実行する。
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$PROJECT_DIR/.build/ui-preview}"

cd "$PROJECT_DIR"
swift build
"$PROJECT_DIR/.build/debug/Tokfuel" --ui-preview "$OUT_DIR" -AppleAccentColor 1

# ウィンドウサーバに繋がらない環境では中身が空の画像ができてしまう。それを見逃さないよう、
# 各ファイルの寸法と容量で描画できたことを確かめる（About はポップオーバーより小さいので
# Scripts/screenshot.sh より緩いしきい値にする）。
shopt -s nullglob
files=("$OUT_DIR"/*.png)
if [ ${#files[@]} -eq 0 ]; then
  echo "no PNGs were written to $OUT_DIR" >&2
  exit 1
fi

for f in "${files[@]}"; do
  WIDTH=$(sips -g pixelWidth "$f" | awk '/pixelWidth:/ { print $2 }')
  HEIGHT=$(sips -g pixelHeight "$f" | awk '/pixelHeight:/ { print $2 }')
  BYTES=$(stat -f%z "$f")

  if [ "${WIDTH:-0}" -lt 200 ] || [ "${HEIGHT:-0}" -lt 200 ]; then
    echo "$f has unexpected dimensions: ${WIDTH}x${HEIGHT}" >&2
    exit 1
  fi
  if [ "$BYTES" -lt 5000 ]; then
    echo "$f looks blank: only ${BYTES} bytes" >&2
    exit 1
  fi
  echo "wrote $f (${WIDTH}x${HEIGHT}, ${BYTES} bytes)"
done
