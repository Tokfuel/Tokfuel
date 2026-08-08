#!/usr/bin/env bash
# Core 6 AX E2E: MenuBar-01, Cost-01/02/03, Settings-01/02
# usage: bash App/E2E/run-core6.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

RECORDING="${TOKFUEL_E2E_RECORDING:-$ROOT/App/E2E/recordings/core6.json}"
WRITE_RECORDING="${TOKFUEL_E2E_WRITE_RECORDING:-$ROOT/.build/e2e/core6-last.json}"

launch_settle() {
  if [[ -f "$RECORDING" ]] && command -v python3 >/dev/null; then
    python3 - "$RECORDING" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    print(float(data.get("launchSettleSeconds", 2.0)))
except Exception:
    print(2.0)
PY
  else
    echo 2.0
  fi
}

echo "Building Tokfuel + TokfuelE2E…"
# SwiftPM は複数 --product を渡すと最後だけビルドすることがあるため、分けて呼ぶ。
# キャッシュが効いていれば差分コンパイルのみで終わる。
swift build --product Tokfuel
swift build --product TokfuelE2E

BIN_DIR="$ROOT/.build/debug"
APP="$BIN_DIR/Tokfuel"
DRIVER="$BIN_DIR/TokfuelE2E"

if [[ "${TOKFUEL_E2E_GRANT_TCC:-}" == "1" ]]; then
  bash "$ROOT/App/E2E/grant-tcc.sh" "$DRIVER" "$APP" /usr/bin/osascript /bin/bash
fi

# Tear down a previous fixture run if any.
pkill -x Tokfuel 2>/dev/null || true
sleep 0.3

SETTLE="$(launch_settle)"
echo "Launching Tokfuel --e2e-fixture… (settle=${SETTLE}s, recording=${RECORDING})"
"$APP" --e2e-fixture -AppleAccentColor 1 &
APP_PID=$!

cleanup() {
  kill "$APP_PID" 2>/dev/null || true
  wait "$APP_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Wait until the process is registered and the status item can appear.
for _ in $(seq 1 40); do
  if kill -0 "$APP_PID" 2>/dev/null; then
    break
  fi
  sleep 0.1
done
sleep "$SETTLE"

echo "Running TokfuelE2E against pid=${APP_PID}..."
"$DRIVER" --pid "$APP_PID" --recording "$RECORDING" --write-recording "$WRITE_RECORDING"
echo "core6 E2E OK"
