#!/bin/bash
# 配布用の Tokfuel.app を dist/ に作り、GitHub Release に添付できる zip を出力する。
# 使い方: bash scripts/release.sh [バージョン]
#   バージョン省略時は Info.plist の CFBundleShortVersionString を使う。
#   Apple Silicon / Intel 両対応のユニバーサルバイナリでビルドする。
#   CODESIGN_IDENTITY を設定すると Developer ID 署名（hardened runtime 有効）になる。
#   未設定ならこれまでどおり ad-hoc 署名（secrets 不要でローカルから実行できる）。
set -euo pipefail

APP_NAME="Tokfuel"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"

VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")}"
VERSION="${VERSION#v}"   # タグ名 v1.2.3 でも 1.2.3 でも受け付ける

echo "Building $APP_NAME $VERSION (universal)..."
cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64

# ユニバーサルビルドの成果物は .build/apple/Products/Release に置かれる
BUILD_DIR="$PROJECT_DIR/.build/apple/Products/Release"

echo "Packaging .app bundle..."
rm -rf "$DIST_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
# SwiftPM のリソースバンドル（retok スクリプト・locales）を同梱する
cp -R "$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle" "$APP_DIR/Contents/Resources/"
cp "$PROJECT_DIR/assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

# 配布物のバージョンをタグに合わせる
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Contents/Info.plist"

SIGN_FLAGS=(--force --sign "${CODESIGN_IDENTITY:--}")
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  echo "Signing with Developer ID identity: $CODESIGN_IDENTITY"
  SIGN_FLAGS+=(--deep --options runtime --timestamp)
else
  echo "CODESIGN_IDENTITY not set — using ad-hoc signing"
fi
codesign "${SIGN_FLAGS[@]}" "$APP_DIR"

ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.zip"
# ditto は Finder 互換の zip を作る（リソースフォークと実行権限を保持する）
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo ""
echo "Done:"
lipo -info "$APP_DIR/Contents/MacOS/$APP_NAME"
shasum -a 256 "$ZIP_PATH"
