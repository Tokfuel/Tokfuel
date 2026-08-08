#!/usr/bin/env bash
# Build the SwiftWasm demo into Demo/wasm/hosted for static hosting.
# Requires: swiftly OSS Swift (not Xcode's /usr/bin/swift), matching Wasm SDK,
# and a Wasm-capable clang (Homebrew llvm is fine).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WASM_DIR="$ROOT/Demo/wasm"
HOSTED="$WASM_DIR/hosted"

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
  echo "  brew install swiftly && swiftly install 6.2.4 && export PATH=\"\$HOME/.swiftly/bin:\$PATH\"" >&2
  exit 1
fi

SDK_ID="${SWIFT_WASM_SDK:-swift-6.2.4-RELEASE_wasm}"
if ! swift sdk list 2>/dev/null | grep -q "$SDK_ID"; then
  echo "error: Swift SDK '$SDK_ID' is not installed." >&2
  echo "  See https://www.swift.org/documentation/articles/wasm-getting-started.html" >&2
  exit 1
fi

cd "$WASM_DIR"
echo "Packaging TokfuelDemo with --swift-sdk $SDK_ID …"
swift package --swift-sdk "$SDK_ID" js -c release

PKG_OUT=".build/plugins/PackageToJS/outputs/Package"
if [[ ! -d "$PKG_OUT" ]]; then
  echo "error: PackageToJS output missing at $PKG_OUT" >&2
  exit 1
fi

rm -rf "$HOSTED"
mkdir -p "$HOSTED"
cp -R "$PKG_OUT"/. "$HOSTED/"
cp "$WASM_DIR/www/index.html" "$HOSTED/index.html"
cp "$ROOT/Demo/html/styles.css" "$HOSTED/styles.css"
: > "$HOSTED/.wasm-ok"
echo "Wrote $HOSTED"
ls -lh "$HOSTED/TokfuelDemo.wasm"
