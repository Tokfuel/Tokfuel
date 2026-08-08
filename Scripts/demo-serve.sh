#!/usr/bin/env bash
# Serve Demo/ locally so fixtures.json and both stacks resolve under /demo/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8765}"
STAGE="$ROOT/.demo-serve"

rm -rf "$STAGE"
mkdir -p "$STAGE/demo"

cp "$ROOT/Demo/compare.html" "$STAGE/demo/index.html"
cp "$ROOT/Demo/fixtures.json" "$STAGE/demo/fixtures.json"
cp -R "$ROOT/Demo/html" "$STAGE/demo/html"

if [[ -d "$ROOT/Demo/wasm/hosted" && -f "$ROOT/Demo/wasm/hosted/TokfuelDemo.wasm" ]]; then
  cp -R "$ROOT/Demo/wasm/hosted" "$STAGE/demo/wasm"
else
  mkdir -p "$STAGE/demo/wasm"
  cp "$ROOT/Demo/wasm/www/index.html" "$STAGE/demo/wasm/index.html"
  cp "$ROOT/Demo/html/styles.css" "$STAGE/demo/wasm/styles.css"
  cat > "$STAGE/demo/wasm/MISSING.txt" <<'EOF'
Wasm hosted artifacts are missing.
Run: bash Scripts/build-wasm-demo.sh
EOF
fi

# Convenience root redirect.
cat > "$STAGE/index.html" <<'EOF'
<!DOCTYPE html><meta http-equiv="refresh" content="0; url=demo/">
EOF

echo "Serving Demo at http://127.0.0.1:${PORT}/demo/"
echo "  HTML:  http://127.0.0.1:${PORT}/demo/html/"
echo "  Wasm:  http://127.0.0.1:${PORT}/demo/wasm/"
cd "$STAGE"
exec python3 -m http.server "$PORT" --bind 127.0.0.1
