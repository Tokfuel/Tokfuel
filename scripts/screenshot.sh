#!/bin/bash
# README 用スクリーンショット (assets/screenshot.png) を実物の UI から生成する（TF-0015）。
# 使い方: bash scripts/screenshot.sh [出力先]
#
# 絵の中身（フィクスチャ・レイアウト）は Tokfuel/Sources/ScreenshotRenderer.swift が持つ。
# ここで渡す起動引数には理由がある:
#   -AppleAccentColor 1  グラフやメーターの色は生成機のシステムアクセントカラーに従い、
#                        AppKit は起動時にそれを読む。ブランドのオレンジに固定して、
#                        どの機械・CI でも同じ絵になるようにする。
# --screenshot は #if DEBUG のため、debug ビルドのバイナリで実行する。
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PROJECT_DIR/assets/screenshot.png}"

cd "$PROJECT_DIR"
swift build
"$PROJECT_DIR/.build/debug/Tokfuel" --screenshot "$OUT" -AppleAccentColor 1

# ウィンドウサーバに繋がらない環境では中身が空の画像ができてしまう。
# それを README にコミットしないよう、寸法と容量で描画できたことを確かめる。
WIDTH=$(sips -g pixelWidth "$OUT" | awk '/pixelWidth:/ { print $2 }')
HEIGHT=$(sips -g pixelHeight "$OUT" | awk '/pixelHeight:/ { print $2 }')
BYTES=$(stat -f%z "$OUT")

if [ "${WIDTH:-0}" -lt 1000 ] || [ "${HEIGHT:-0}" -lt 1000 ]; then
  echo "screenshot has unexpected dimensions: ${WIDTH}x${HEIGHT}" >&2
  exit 1
fi
if [ "$BYTES" -lt 40000 ]; then
  echo "screenshot looks blank: only ${BYTES} bytes" >&2
  exit 1
fi

echo "wrote $OUT (${WIDTH}x${HEIGHT}, ${BYTES} bytes)"
