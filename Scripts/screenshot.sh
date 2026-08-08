#!/bin/bash
# README / Site 用スクリーンショットを実物の UI から生成する（TF-0015 / #62）。
# 使い方:
#   bash Scripts/screenshot.sh              # Assets/ と Site/Assets/ の両方へ書き出す
#   bash Scripts/screenshot.sh <出力先>     # 指定パスだけへ書き出す（検証・デバッグ用）
#
# 絵の中身（フィクスチャ・レイアウト）は App/Tokfuel/ScreenshotRenderer.swift が持つ。
# ここで渡す起動引数には理由がある:
#   -AppleAccentColor 1  グラフやメーターの色は生成機のシステムアクセントカラーに従い、
#                        AppKit は起動時にそれを読む。ブランドのオレンジに固定して、
#                        どの機械・CI でも同じ絵になるようにする。
# --screenshot は #if DEBUG のため、debug ビルドのバイナリで実行する。
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
README_OUT="$PROJECT_DIR/Assets/screenshot.png"
SITE_OUT="$PROJECT_DIR/Site/Assets/images/screenshot.png"

if [ "${1:-}" != "" ]; then
  OUTS=("$1")
else
  OUTS=("$README_OUT" "$SITE_OUT")
fi

cd "$PROJECT_DIR"
swift build

# 1 回だけ描画し、必要なら同じ PNG を両パスへ配る（描画コストを二重に払わない）。
PRIMARY="${OUTS[0]}"
"$PROJECT_DIR/.build/debug/Tokfuel" --screenshot "$PRIMARY" -AppleAccentColor 1

# ウィンドウサーバに繋がらない環境では中身が空の画像ができてしまう。
# それを README / Site にコミットしないよう、寸法と容量で描画できたことを確かめる。
WIDTH=$(sips -g pixelWidth "$PRIMARY" | awk '/pixelWidth:/ { print $2 }')
HEIGHT=$(sips -g pixelHeight "$PRIMARY" | awk '/pixelHeight:/ { print $2 }')
BYTES=$(stat -f%z "$PRIMARY")

if [ "${WIDTH:-0}" -lt 1000 ] || [ "${HEIGHT:-0}" -lt 1000 ]; then
  echo "screenshot has unexpected dimensions: ${WIDTH}x${HEIGHT}" >&2
  exit 1
fi
if [ "$BYTES" -lt 40000 ]; then
  echo "screenshot looks blank: only ${BYTES} bytes" >&2
  exit 1
fi

for OUT in "${OUTS[@]:1}"; do
  mkdir -p "$(dirname "$OUT")"
  cp "$PRIMARY" "$OUT"
done

for OUT in "${OUTS[@]}"; do
  echo "wrote $OUT (${WIDTH}x${HEIGHT}, ${BYTES} bytes)"
done
