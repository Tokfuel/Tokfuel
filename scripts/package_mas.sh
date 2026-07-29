#!/bin/bash
# Mac App Store 提出用の署名済み .pkg を dist-mas/ に作る。
# 使い方: bash scripts/package_mas.sh [バージョン]
#   バージョン省略時は Info.plist の CFBundleShortVersionString を使う。
# 必要 env:
#   MAS_PROVISIONING_PROFILE_PATH  … .provisionprofile のパス（署名時必須）
#   MAS_APP_SIGNING_IDENTITY       … 省略時 "Apple Distribution"
#   MAS_INSTALLER_SIGNING_IDENTITY … 省略時 "3rd Party Mac Developer Installer"
#   TOKFUEL_BUILD_NUMBER           … 省略時 git rev-list --count HEAD
#   TOKFUEL_SKIP_SIGNING=1         … 証明書なしのドライラン（検証用）
set -euo pipefail

APP_NAME="Tokfuel"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist-mas"
APP_DIR="$DIST_DIR/${APP_NAME}.app"

VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")}"
VERSION="${VERSION#v}"   # タグ名 v1.2.3 でも 1.2.3 でも受け付ける
# App Store はビルド番号の単調増加を要求する。main のコミット数なら
# CI でもローカルでも同じ値が再現でき、別途カウンタを持たずに済む。
BUILD_NUMBER="${TOKFUEL_BUILD_NUMBER:-$(git -C "$PROJECT_DIR" rev-list --count HEAD)}"

echo "Building $APP_NAME $VERSION build $BUILD_NUMBER (universal, Mac App Store)..."
cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64

# ユニバーサルビルドの成果物は .build/apple/Products/Release に置かれる
BUILD_DIR="$PROJECT_DIR/.build/apple/Products/Release"

echo "Packaging .app bundle..."
rm -rf "$DIST_DIR"
source "$PROJECT_DIR/scripts/lib/assemble_app.sh"
assemble_app "$BUILD_DIR" "$APP_DIR"

# 配布物のバージョン・ビルド番号をタグに合わせる
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"

PKG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.pkg"
if [ "${TOKFUEL_SKIP_SIGNING:-0}" = "1" ]; then
  # 証明書を持たない環境でパッケージングまでを検証するためのドライラン
  codesign --force --sign - "$APP_DIR"
  productbuild --component "$APP_DIR" /Applications "$PKG_PATH"
else
  cp "${MAS_PROVISIONING_PROFILE_PATH:?}" "$APP_DIR/Contents/embedded.provisionprofile"
  # Xcode が署名時に自動注入する application-identifier / team-identifier を
  # 手動で足す。これがないと App Store Connect のアップロード検証で弾かれる。
  TEAM_ID="${TOKFUEL_TEAM_ID:?App Store 署名には TOKFUEL_TEAM_ID（チーム ID）が必要}"
  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_DIR/Contents/Info.plist")"
  ENTITLEMENTS="$DIST_DIR/Tokfuel.entitlements"
  cp "$PROJECT_DIR/Tokfuel.entitlements" "$ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $TEAM_ID.$BUNDLE_ID" "$ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $TEAM_ID" "$ENTITLEMENTS"
  # MAS はサンドボックス（entitlements）で署名する。--options runtime
  # （hardened runtime）は Developer ID 公証用なのでここでは付けない。
  codesign --force --timestamp \
    --sign "${MAS_APP_SIGNING_IDENTITY:-Apple Distribution}" \
    --entitlements "$ENTITLEMENTS" \
    "$APP_DIR"
  productbuild --component "$APP_DIR" /Applications \
    --sign "${MAS_INSTALLER_SIGNING_IDENTITY:-3rd Party Mac Developer Installer}" \
    "$PKG_PATH"
fi

echo ""
echo "Done:"
lipo -info "$APP_DIR/Contents/MacOS/$APP_NAME"
shasum -a 256 "$PKG_PATH"
