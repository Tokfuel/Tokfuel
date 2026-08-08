#!/usr/bin/env bash
# E2E メニューバー（コアシナリオ 6 本）:
# MenuBar-01, Cost-01/02/03, Settings-01/02
# usage: bash App/E2E/run-core6.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

RECORDING="${TOKFUEL_E2E_RECORDING:-$ROOT/App/E2E/recordings/core6.json}"
WRITE_RECORDING="${TOKFUEL_E2E_WRITE_RECORDING:-$ROOT/.build/e2e/core6-last.json}"
REPORT="${TOKFUEL_E2E_REPORT:-$ROOT/.build/e2e/report.json}"
OUT_DIR="$ROOT/.build/e2e"
mkdir -p "$OUT_DIR"

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
swift build --product Tokfuel
swift build --product TokfuelE2E

BIN_DIR="$ROOT/.build/debug"
APP="$BIN_DIR/Tokfuel"
DRIVER="$BIN_DIR/TokfuelE2E"

if [[ "${TOKFUEL_E2E_GRANT_TCC:-}" == "1" ]]; then
  bash "$ROOT/App/E2E/grant-tcc.sh" \
    "$DRIVER" "$APP" /usr/bin/osascript /bin/bash /usr/sbin/screencapture
fi

pkill -x Tokfuel 2>/dev/null || true
sleep 0.3

SETTLE="$(launch_settle)"
echo "Launching Tokfuel --e2e-fixture… (settle=${SETTLE}s, recording=${RECORDING})"
"$APP" --e2e-fixture -AppleAccentColor 1 &
APP_PID=$!

FRAME_PID=""
cleanup() {
  if [[ -n "${FRAME_PID:-}" ]] && kill -0 "$FRAME_PID" 2>/dev/null; then
    kill "$FRAME_PID" 2>/dev/null || true
    wait "$FRAME_PID" 2>/dev/null || true
  fi
  kill "$APP_PID" 2>/dev/null || true
  wait "$APP_PID" 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 40); do
  if kill -0 "$APP_PID" 2>/dev/null; then
    break
  fi
  sleep 0.1
done
sleep "$SETTLE"

# 失敗時に「そのときの様子」を残す。
# screencapture -v は Screen Recording の Allow ダイアログで止まりやすいので使わない。
# 代わりに 1 秒ごとの PNG を撮り、失敗時に ffmpeg で failure.mov を合成する。
VIDEO_OUT="$OUT_DIR/failure.mov"
FRAMES_DIR="$OUT_DIR/frames"
rm -f "$VIDEO_OUT"
rm -rf "$FRAMES_DIR"
mkdir -p "$FRAMES_DIR"
(
  i=0
  while kill -0 "$APP_PID" 2>/dev/null; do
    /usr/sbin/screencapture -x "$FRAMES_DIR/frame-$(printf '%02d' "$i").png" 2>/dev/null || true
    i=$((i + 1))
    [[ "$i" -ge 40 ]] && break
    sleep 1
  done
) &
FRAME_PID=$!
echo "frame capture pid=${FRAME_PID} → ${FRAMES_DIR}"

echo "Running TokfuelE2E against pid=${APP_PID}..."
set +e
"$DRIVER" --pid "$APP_PID" \
  --recording "$RECORDING" \
  --write-recording "$WRITE_RECORDING" \
  --report "$REPORT"
DRIVER_STATUS=$?
set -e

# フレーム取得を止める（成功時は証拠を捨てる）。
if [[ -n "${FRAME_PID}" ]]; then
  kill "$FRAME_PID" 2>/dev/null || true
  wait "$FRAME_PID" 2>/dev/null || true
  FRAME_PID=""
fi

if [[ "$DRIVER_STATUS" -eq 0 ]]; then
  rm -f "$VIDEO_OUT"
  rm -rf "$FRAMES_DIR"
  echo "E2E メニューバー OK"
  exit 0
fi

echo "E2E メニューバー FAILED (status=${DRIVER_STATUS}); capturing evidence…"
/usr/sbin/screencapture -x "$OUT_DIR/failure.png" || true

shopt -s nullglob
frames=("$FRAMES_DIR"/frame-*.png)
if [[ ${#frames[@]} -gt 0 ]]; then
  cp "${frames[0]}" "$OUT_DIR/timeline-start.png"
  mid=$(( ${#frames[@]} / 2 ))
  cp "${frames[$mid]}" "$OUT_DIR/timeline-mid.png"
  cp "${frames[$(( ${#frames[@]} - 1 ))]}" "$OUT_DIR/timeline-end.png"

  # Allow ダイアログ不要: PNG 連番から動画を合成する。
  if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -hide_banner -loglevel error \
      -framerate 1 \
      -pattern_type glob -i "$FRAMES_DIR/frame-*.png" \
      -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
      "$VIDEO_OUT" \
      && echo "synthesized failure.mov from ${#frames[@]} frames" \
      || echo "warning: ffmpeg failed to synthesize failure.mov" >&2
  else
    echo "warning: ffmpeg not found; skip failure.mov" >&2
  fi
fi

# 正常時の参照画面（フィクスチャ描画）。失敗シナリオに応じて popover / settings を残す。
EXPECTED_DIR="$OUT_DIR/expected"
rm -rf "$EXPECTED_DIR"
mkdir -p "$EXPECTED_DIR"
if "$APP" --ui-preview "$EXPECTED_DIR" >/dev/null 2>&1; then
  echo "expected screens written under ${EXPECTED_DIR}"
else
  echo "warning: failed to render expected ui-preview screens" >&2
fi

# レポートが無い場合の最低限フォールバック。
if [[ ! -f "$REPORT" ]]; then
  cat > "$REPORT" <<EOF
{"ok":false,"failedScenario":null,"error":"driver exited ${DRIVER_STATUS}","explanation":"ドライバが非ゼロで終了しました。","completedScenarios":[],"scenarios":[],"baselineIdentifiers":[],"expectedScreens":["popover"],"updatedAt":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
fi

exit "$DRIVER_STATUS"
