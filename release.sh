#!/bin/bash
set -euo pipefail

# Developer ID 署名 + 公証 (notarization) 済みのリリースビルドを作る。
# App Store ではなく「直接配布（GitHub Releases / Homebrew Cask 等）」向け。
#
# ── 事前準備（初回だけ）─────────────────────────────────────────────
#  1) Apple Developer で "Developer ID Application" 証明書を作成し Keychain へ:
#       Xcode → Settings → Accounts → (Apple ID) → Manage Certificates
#       → 左下 + → "Developer ID Application"
#     確認: security find-identity -v -p codesigning | grep "Developer ID Application"
#
#  2) 公証用の認証情報を Keychain プロファイルに保存（App 用パスワードは
#     https://account.apple.com → サインインとセキュリティ → App 用パスワード で発行）:
#       xcrun notarytool store-credentials tokfuel-notary \
#         --apple-id "you@example.com" --team-id "TEAMID" --password "xxxx-xxxx-xxxx-xxxx"
#
# ── 使い方 ───────────────────────────────────────────────────────────
#   DEV_ID="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="tokfuel-notary" \
#   ./release.sh
#
# 出力: dist/Tokfuel.app（公証・ステープル済み）と dist/Tokfuel.zip

APP_NAME="Tokfuel"
BUNDLE_NAME="Tokfuel"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
ZIP_PATH="$DIST_DIR/${BUNDLE_NAME}.zip"
RES_BUNDLE="${BUNDLE_NAME}_${BUNDLE_NAME}.bundle"

: "${DEV_ID:?Set DEV_ID to your 'Developer ID Application: NAME (TEAMID)' identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool keychain profile name}"

echo "==> Building release binary"
cd "$PROJECT_DIR"
swift build -c release

echo "==> Assembling .app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$BUNDLE_NAME" "$APP_DIR/Contents/MacOS/$BUNDLE_NAME"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp -R "$BUILD_DIR/$RES_BUNDLE" "$APP_DIR/Contents/Resources/"
cp "$PROJECT_DIR/assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "==> Codesigning with hardened runtime (inside-out)"
# 内側のリソースバンドル → 実行ファイル → .app の順に署名する（--deep は使わない）
codesign --force --options runtime --timestamp --sign "$DEV_ID" \
  "$APP_DIR/Contents/Resources/$RES_BUNDLE"
codesign --force --options runtime --timestamp --sign "$DEV_ID" \
  "$APP_DIR/Contents/MacOS/$BUNDLE_NAME"
codesign --force --options runtime --timestamp --sign "$DEV_ID" "$APP_DIR"
codesign --verify --strict --verbose=2 "$APP_DIR"

echo "==> Zipping for notarization"
/usr/bin/ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "==> Submitting to Apple notary service (may take a few minutes)"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling ticket"
xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"
spctl --assess --type execute --verbose=2 "$APP_DIR"

echo "==> Re-zipping stapled app for distribution"
rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo ""
echo "Done. Distributable (notarized + stapled):"
echo "  $APP_DIR"
echo "  $ZIP_PATH"
