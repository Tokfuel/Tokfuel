#!/usr/bin/env bash
# E2E 成功時の実画面（popover / settings）を orphan ブランチ e2e-baselines へ上書き保存する。
#
# usage: bash App/Tests/E2E/publish-baselines.sh
# env:
#   GH_TOKEN（push に必要。Actions では github.token）
#   REPO（例: Tokfuel/Tokfuel）
#   GITHUB_SHA / PR_SHA（meta 用）
#   GITHUB_RUN_ID（optional）
#   TOKFUEL_E2E_PUBLISH_BASELINES=1（ローカルで明示するとき必須。CI では不要）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

BASELINE_DIR="${TOKFUEL_E2E_BASELINE_DIR:-$ROOT/.build/e2e/baseline}"
BRANCH="e2e-baselines"

if [[ ! -f "$BASELINE_DIR/popover.png" && ! -f "$BASELINE_DIR/settings.png" ]]; then
  echo "no baselines under $BASELINE_DIR; skip publish" >&2
  exit 0
fi

# ローカル誤 push 防止。CI（GITHUB_ACTIONS）か明示フラグのみ。
if [[ "${GITHUB_ACTIONS:-}" != "true" && "${TOKFUEL_E2E_PUBLISH_BASELINES:-}" != "1" ]]; then
  echo "skip publish-baselines (set TOKFUEL_E2E_PUBLISH_BASELINES=1 to force)" >&2
  exit 0
fi

: "${GH_TOKEN:?}"
: "${REPO:?}"

SHA="${GITHUB_SHA:-${PR_SHA:-}}"
SHORT_SHA="${SHA:0:7}"
RUN_URL=""
if [[ -n "${GITHUB_RUN_ID:-}" ]]; then
  RUN_URL="https://github.com/${REPO}/actions/runs/${GITHUB_RUN_ID}"
fi

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

STAGE="$(mktemp -d)"
[[ -f "$BASELINE_DIR/popover.png" ]] && cp "$BASELINE_DIR/popover.png" "$STAGE/popover.png"
[[ -f "$BASELINE_DIR/settings.png" ]] && cp "$BASELINE_DIR/settings.png" "$STAGE/settings.png"

export REPO SHA RUN_URL
python3 - "$STAGE" <<'PY'
import json, os, sys
from datetime import datetime, timezone
stage = sys.argv[1]
screens = [name for name in ("popover", "settings")
           if os.path.isfile(os.path.join(stage, f"{name}.png"))]
meta = {
    "sha": os.environ.get("SHA") or "",
    "updatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "runUrl": os.environ.get("RUN_URL") or "",
    "screens": screens,
}
with open(os.path.join(stage, "meta.json"), "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY

git fetch origin "$BRANCH" 2>/dev/null || true
if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  git switch -C "$BRANCH" "origin/$BRANCH"
else
  git switch --orphan "$BRANCH"
  git rm -rf . > /dev/null 2>&1 || true
fi

# 安定名で上書き（失敗証拠の pr-* とは別ブランチ）。
rm -f popover.png settings.png meta.json
cp -f "$STAGE"/* .
rm -rf "$STAGE" .build .swiftpm

git add -- meta.json
[[ -f popover.png ]] && git add -- popover.png
[[ -f settings.png ]] && git add -- settings.png
if git diff --cached --quiet; then
  echo "baselines unchanged; skip commit" >&2
  exit 0
fi

MSG="chore: e2e baselines"
if [[ -n "$SHORT_SHA" ]]; then
  MSG="${MSG} (${SHORT_SHA})"
fi
git commit -m "$MSG"
git push origin "$BRANCH"
echo "published baselines to ${BRANCH}"
if [[ -n "$RUN_URL" ]]; then
  echo "from ${RUN_URL}"
fi
