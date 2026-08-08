#!/usr/bin/env bash
# Build the SwiftUI-shaped DemoUI wasm host into Demo/wasm/hosted.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEMO_DIR="$ROOT/Demo"
HOSTED="$DEMO_DIR/wasm/hosted"

prefer_path() {
  if [[ -x "$HOME/.swiftly/bin/swift" ]]; then
    export PATH="$HOME/.swiftly/bin:$PATH"
  fi
  if [[ -x /opt/homebrew/opt/llvm/bin/clang ]]; then
    export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
    export CC=/opt/homebrew/opt/llvm/bin/clang
    export CXX=/opt/homebrew/opt/llvm/bin/clang++
  fi
}

prefer_path

if ! swift --version 2>/dev/null | grep -q 'swift-.*-RELEASE'; then
  echo "error: need OSS Swift from swiftly (Xcode Swift cannot target wasm32-unknown-wasip1)." >&2
  exit 1
fi

SDK_ID="${SWIFT_WASM_SDK:-swift-6.2.4-RELEASE_wasm}"
if ! swift sdk list 2>/dev/null | grep -q "$SDK_ID"; then
  echo "error: Swift SDK '$SDK_ID' is not installed." >&2
  exit 1
fi

cd "$DEMO_DIR"
# Remove legacy nested package if present
rm -f wasm/Package.swift wasm/Package.resolved

echo "Packaging TokfuelDemo (DemoUI + local TokamakDOM shim)…"
swift package --swift-sdk "$SDK_ID" js -c release

PKG_OUT=".build/plugins/PackageToJS/outputs/Package"
if [[ ! -d "$PKG_OUT" ]]; then
  echo "error: PackageToJS output missing at $PKG_OUT" >&2
  exit 1
fi

rm -rf "$HOSTED"
mkdir -p "$HOSTED"
cp -R "$PKG_OUT"/. "$HOSTED/"
cp "$DEMO_DIR/wasm/www/index.html" "$HOSTED/index.html"
# Prefer DemoUI look; fall back to html styles if present
if [[ -f "$DEMO_DIR/html/styles.css" ]]; then
  cp "$DEMO_DIR/html/styles.css" "$HOSTED/styles.css"
fi
: > "$HOSTED/.wasm-ok"
echo "Wrote $HOSTED"
ls -lh "$HOSTED/TokfuelDemo.wasm"
