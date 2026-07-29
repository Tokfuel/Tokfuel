#!/bin/bash
# 配布用の Tokfuel.app を dist/ に作り、GitHub Release に添付できる zip を出力する。
# 使い方: bash scripts/release.sh [バージョン]
#   バージョン省略時は Info.plist の CFBundleShortVersionString を使う。
#   Apple Silicon / Intel 両対応のユニバーサルバイナリでビルドする。
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
source "$PROJECT_DIR/scripts/lib/assemble_app.sh"
assemble_app "$BUILD_DIR" "$APP_DIR"

# 配布物のバージョンをタグに合わせる
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Contents/Info.plist"

codesign --force --sign - "$APP_DIR"

ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.zip"
# ditto は Finder 互換の zip を作る（リソースフォークと実行権限を保持する）
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo ""
echo "Done:"
lipo -info "$APP_DIR/Contents/MacOS/$APP_NAME"
shasum -a 256 "$ZIP_PATH"
