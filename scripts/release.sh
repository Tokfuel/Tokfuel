#!/bin/bash
# 配布用の Tokfuel.app を dist/ に作り、GitHub Release に添付できる
# drag-to-Applications DMG を出力する。
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
source "$PROJECT_DIR/scripts/package-app.sh"

VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")}"
VERSION="${VERSION#v}"   # タグ名 v1.2.3 でも 1.2.3 でも受け付ける

echo "Building $APP_NAME $VERSION (universal, TOKFUEL_DISTRIBUTION)..."
cd "$PROJECT_DIR"
# -DTOKFUEL_DISTRIBUTION が付いたビルドだけ Crashlytics / Analytics を有効化する（#22）。
# 手元の swift build / scripts/build.sh には付けない。
swift build -c release --arch arm64 --arch x86_64 \
  -Xswiftc -DTOKFUEL_DISTRIBUTION

# ユニバーサルビルドの成果物は .build/apple/Products/Release に置かれる
BUILD_DIR="$PROJECT_DIR/.build/apple/Products/Release"

echo "Packaging .app bundle..."
rm -rf "$DIST_DIR"
package_tokfuel_app "$BUILD_DIR" "$APP_DIR" "$PROJECT_DIR"

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

# Crashlytics 用 dSYM を生成してアップロード（失敗しても配布物自体は残す）。
upload_crashlytics_dsym "$APP_DIR" "$PROJECT_DIR" || \
  echo "warning: Crashlytics dSYM upload skipped or failed" >&2

echo "Building DMG..."
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"
TMP_DMG="$DIST_DIR/${APP_NAME}-tmp.dmg"

rm -rf "$STAGING_DIR" "$DMG_PATH" "$TMP_DMG"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDRW "$TMP_DMG"

MOUNT_DIR="/Volumes/$APP_NAME"
# -nobrowse は付けない — Finder から見えない volume は下のレイアウト用
# AppleScript が "disk" を見つけられず失敗する
hdiutil attach "$TMP_DMG" -noautoopen
# アタッチ直後は Finder がまだ volume を認識していないことがあるので一呼吸置く
sleep 2

# アイコンを並べて Applications へドラッグできるウィンドウにする
# （create-dmg 系ツールが行っている定番の Finder AppleScript レイアウト）
osascript <<EOF
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 100, 940, 460}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set position of item "$APP_NAME.app" of container window to {140, 180}
    set position of item "Applications" of container window to {400, 180}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
EOF

sync
hdiutil detach "$MOUNT_DIR"

hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG_PATH"
rm -f "$TMP_DMG"
rm -rf "$STAGING_DIR"

echo ""
echo "Done:"
lipo -info "$APP_DIR/Contents/MacOS/$APP_NAME"
shasum -a 256 "$DMG_PATH"
