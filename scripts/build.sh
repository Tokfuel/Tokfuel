#!/bin/bash
set -euo pipefail

APP_NAME="Tokfuel"
BUNDLE_NAME="Tokfuel"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="/Applications/${APP_NAME}.app"

# 既定は配布と同じ release 構成。--debug は開発者向けのデバッグセクション
# （設定の一番下）を含む debug 構成を入れる。配布物には使わない。
CONFIG="release"
if [[ "${1:-}" == "--debug" ]]; then
  CONFIG="debug"
fi
BUILD_DIR="$PROJECT_DIR/.build/$CONFIG"

echo "Building $APP_NAME ($CONFIG)..."
cd "$PROJECT_DIR"
swift build -c "$CONFIG" 2>&1

echo "Packaging .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$BUNDLE_NAME" "$APP_DIR/Contents/MacOS/$BUNDLE_NAME"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
# SwiftPM のリソースバンドル（retok スクリプト・locales）を同梱する
cp -R "$BUILD_DIR/${BUNDLE_NAME}_${BUNDLE_NAME}.bundle" "$APP_DIR/Contents/Resources/"
# アプリアイコン
cp "$PROJECT_DIR/assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP_DIR" 2>/dev/null || true

echo "Installed to $APP_DIR"
echo ""

if pgrep -f "$BUNDLE_NAME" > /dev/null 2>&1; then
  echo "Restarting..."
  pkill -f "$BUNDLE_NAME" 2>/dev/null || true
  sleep 1
fi

echo "Launching..."
open "$APP_DIR"
echo "Done."
