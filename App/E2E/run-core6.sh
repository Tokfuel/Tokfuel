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
DISMISS_PID=""
cleanup() {
  if [[ -n "${DISMISS_PID:-}" ]] && kill -0 "$DISMISS_PID" 2>/dev/null; then
    kill "$DISMISS_PID" 2>/dev/null || true
    wait "$DISMISS_PID" 2>/dev/null || true
  fi
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
# screencapture -v は使わず、0.2 秒ごとの PNG を ffmpeg で failure.mov / .gif にする。
# 静止画でも Screen Recording の Allow が出ることがあるので、dismiss を並行起動する。
VIDEO_OUT="$OUT_DIR/failure.mov"
GIF_OUT="$OUT_DIR/failure.gif"
COMPARE_OUT="$OUT_DIR/compare.png"
FRAMES_DIR="$OUT_DIR/frames"
FRAME_INTERVAL="0.2"
FRAME_FPS="5"
FRAME_MAX="150"
rm -f "$VIDEO_OUT" "$GIF_OUT" "$COMPARE_OUT"
rm -rf "$FRAMES_DIR"
mkdir -p "$FRAMES_DIR"

# Allow が出るのは最初の数キャプチャが多い。長く回すと System Events が E2E と競合する。
bash "$ROOT/App/E2E/dismiss-tcc-prompt.sh" 12 &
DISMISS_PID=$!
echo "tcc dismiss pid=${DISMISS_PID} (first 12s)"

(
  i=0
  while kill -0 "$APP_PID" 2>/dev/null; do
    /usr/sbin/screencapture -x "$FRAMES_DIR/frame-$(printf '%03d' "$i").png" 2>/dev/null || true
    i=$((i + 1))
    [[ "$i" -ge "$FRAME_MAX" ]] && break
    sleep "$FRAME_INTERVAL"
  done
) &
FRAME_PID=$!
echo "frame capture pid=${FRAME_PID} → ${FRAMES_DIR} (every ${FRAME_INTERVAL}s)"

echo "Running TokfuelE2E against pid=${APP_PID}..."
set +e
"$DRIVER" --pid "$APP_PID" \
  --recording "$RECORDING" \
  --write-recording "$WRITE_RECORDING" \
  --report "$REPORT"
DRIVER_STATUS=$?
set -e

# フレーム取得 / Allow 監視を止める（成功時は証拠を捨てる）。
if [[ -n "${DISMISS_PID}" ]]; then
  kill "$DISMISS_PID" 2>/dev/null || true
  wait "$DISMISS_PID" 2>/dev/null || true
  DISMISS_PID=""
fi
if [[ -n "${FRAME_PID}" ]]; then
  kill "$FRAME_PID" 2>/dev/null || true
  wait "$FRAME_PID" 2>/dev/null || true
  FRAME_PID=""
fi

if [[ "$DRIVER_STATUS" -eq 0 ]]; then
  rm -f "$VIDEO_OUT" "$GIF_OUT" "$COMPARE_OUT"
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

  # PNG 連番から動画 / GIF を合成（再生も 0.2 秒/コマ = 5 fps）。
  if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -hide_banner -loglevel error \
      -framerate "$FRAME_FPS" \
      -pattern_type glob -i "$FRAMES_DIR/frame-*.png" \
      -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
      "$VIDEO_OUT" \
      && echo "synthesized failure.mov from ${#frames[@]} frames @ ${FRAME_FPS}fps" \
      || echo "warning: ffmpeg failed to synthesize failure.mov" >&2
    ffmpeg -y -hide_banner -loglevel error \
      -framerate "$FRAME_FPS" \
      -pattern_type glob -i "$FRAMES_DIR/frame-*.png" \
      -vf "scale=720:-1:flags=lanczos,fps=${FRAME_FPS},split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer" \
      -loop 0 \
      "$GIF_OUT" \
      && echo "synthesized failure.gif from ${#frames[@]} frames @ ${FRAME_FPS}fps" \
      || echo "warning: ffmpeg failed to synthesize failure.gif" >&2
  else
    echo "warning: ffmpeg not found; skip failure.mov / failure.gif" >&2
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

# 成功（期待）と失敗（実際）を横並びにした比較画像（緑枠 / 赤枠）。
if command -v ffmpeg >/dev/null 2>&1 && [[ -f "$OUT_DIR/failure.png" ]]; then
  expected_png=""
  if [[ -f "$REPORT" ]] && command -v python3 >/dev/null; then
    expected_png="$(python3 - "$REPORT" "$EXPECTED_DIR" <<'PY'
import json, os, sys
r = json.load(open(sys.argv[1]))
root = sys.argv[2]
for name in r.get("expectedScreens") or ["popover"]:
    path = os.path.join(root, f"{name}.png")
    if os.path.isfile(path):
        print(path)
        break
PY
)"
  fi
  if [[ -z "$expected_png" ]]; then
    for name in settings popover; do
      if [[ -f "$EXPECTED_DIR/${name}.png" ]]; then
        expected_png="$EXPECTED_DIR/${name}.png"
        break
      fi
    done
  fi
  if [[ -n "$expected_png" ]]; then
    # 緑=成功（期待） / 赤=失敗（実際）。ラベルはコメント側の見出しで示す。
    ffmpeg -y -hide_banner -loglevel error \
      -i "$expected_png" -i "$OUT_DIR/failure.png" \
      -filter_complex "\
        [0:v]scale=-1:360,pad=iw+24:ih+24:12:12:color=0x1a7f37[left];\
        [1:v]scale=-1:360,pad=iw+24:ih+24:12:12:color=0xc41e3a[right];\
        [left][right]hstack=inputs=2[out]" \
      -map '[out]' "$COMPARE_OUT" \
      && echo "wrote compare.png (expected vs failure)" \
      || echo "warning: failed to synthesize compare.png" >&2
  fi
fi

exit "$DRIVER_STATUS"
