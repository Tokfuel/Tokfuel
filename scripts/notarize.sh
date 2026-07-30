#!/bin/bash
# dist/ にある署名済み .app を公証（notarize）し、公証チケットを staple してから
# GitHub Release 用の zip を作り直す。App Store Connect API キーが必要なので CI 専用。
# 使い方: bash scripts/notarize.sh <バージョン（scripts/release.sh に渡したものと同じ）>
#   環境変数: APP_STORE_CONNECT_KEY_ID / APP_STORE_CONNECT_ISSUER_ID /
#             APP_STORE_CONNECT_KEY_PATH（.p8 のパス）
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/Tokfuel.app"

VERSION="${1:?version argument is required (same value passed to release.sh)}"
VERSION="${VERSION#v}"
ZIP_PATH="$DIST_DIR/Tokfuel-${VERSION}.zip"

: "${APP_STORE_CONNECT_KEY_ID:?APP_STORE_CONNECT_KEY_ID is required}"
: "${APP_STORE_CONNECT_ISSUER_ID:?APP_STORE_CONNECT_ISSUER_ID is required}"
: "${APP_STORE_CONNECT_KEY_PATH:?APP_STORE_CONNECT_KEY_PATH is required}"

# release.sh が作った zip（署名済み .app）をそのまま公証に提出する — 提出用に作り直さない。
echo "Submitting for notarization..."
xcrun notarytool submit "$ZIP_PATH" \
  --key "$APP_STORE_CONNECT_KEY_PATH" \
  --key-id "$APP_STORE_CONNECT_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --wait

echo "Stapling ticket..."
xcrun stapler staple "$APP_DIR"

# staple 後の .app で zip を作り直す（提出した zip は staple 前の内容なので置き換える）
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Notarized and stapled:"
shasum -a 256 "$ZIP_PATH"
