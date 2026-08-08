#!/usr/bin/env bash
# E2E 失敗時に証拠（スクショ・動画・正常画面）を orphan ブランチへ載せ、PR コメントする。
# ui-preview.yml と同じ手法（raw.githubusercontent.com 埋め込み）。
#
# usage: bash App/E2E/comment-failure.sh
# env: GH_TOKEN, PR_NUMBER, PR_SHA, REPO, GITHUB_RUN_ID (optional)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

: "${GH_TOKEN:?}"
: "${PR_NUMBER:?}"
: "${PR_SHA:?}"
: "${REPO:?}"

OUT_DIR="$ROOT/.build/e2e"
REPORT="$OUT_DIR/report.json"
BRANCH="e2e-failure-images"
SHORT_SHA="${PR_SHA:0:7}"
RUN_URL=""
if [[ -n "${GITHUB_RUN_ID:-}" ]]; then
  RUN_URL="https://github.com/${REPO}/actions/runs/${GITHUB_RUN_ID}"
fi

if [[ ! -f "$REPORT" ]]; then
  echo "no report at $REPORT; skip comment" >&2
  exit 0
fi

# レポートをシェル変数へ展開（bash 3.2 / macos）。
eval "$(python3 - "$REPORT" <<'PY'
import json, shlex, sys
r = json.load(open(sys.argv[1]))
def emit(k, v):
    print(f"{k}={shlex.quote('' if v is None else str(v))}")
emit("FAILED_SCENARIO", r.get("failedScenario") or "（不明）")
emit("ERROR", r.get("error") or "（エラー詳細なし）")
emit("EXPLANATION", (r.get("explanation") or "").strip() or "失敗原因の説明を生成できませんでした。")
emit("BASELINE", ", ".join(r.get("baselineIdentifiers") or []))
completed = r.get("completedScenarios") or []
emit("COMPLETED", ", ".join(completed) if completed else "（なし）")
screens = r.get("expectedScreens") or ["popover"]
emit("EXPECTED_SCREENS", " ".join(screens))
rows = []
for s in r.get("scenarios") or []:
    mark = {"passed": "✅", "failed": "❌", "skipped": "⏭"}.get(s.get("status"), "•")
    rows.append(f"{mark} `{s.get('id')}` ({s.get('status')})")
emit("SCENARIO_LIST", "\n".join(rows) if rows else f"❌ `{r.get('failedScenario') or 'unknown'}`")
PY
)"

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# 証拠ファイルを一時退避（orphan switch で消えないように）。
STAGE="$(mktemp -d)"
PREFIX="pr-${PR_NUMBER}-${SHORT_SHA}"
cp "$REPORT" "$STAGE/${PREFIX}-report.json"
[[ -f "$OUT_DIR/failure.png" ]] && cp "$OUT_DIR/failure.png" "$STAGE/${PREFIX}-failure.png"
[[ -f "$OUT_DIR/failure.mov" ]] && cp "$OUT_DIR/failure.mov" "$STAGE/${PREFIX}-failure.mov"
for t in start mid end; do
  [[ -f "$OUT_DIR/timeline-${t}.png" ]] && cp "$OUT_DIR/timeline-${t}.png" "$STAGE/${PREFIX}-timeline-${t}.png"
done
for screen in $EXPECTED_SCREENS; do
  src="$OUT_DIR/expected/${screen}.png"
  if [[ -f "$src" ]]; then
    cp "$src" "$STAGE/${PREFIX}-expected-${screen}.png"
  fi
done

git fetch origin "$BRANCH" 2>/dev/null || true
if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  git switch -C "$BRANCH" "origin/$BRANCH"
else
  git switch --orphan "$BRANCH"
  git rm -rf . > /dev/null 2>&1 || true
fi

# 同じ PR の古い証拠を消してから今回分を載せる。
rm -f "pr-${PR_NUMBER}-"*
cp -f "$STAGE"/"${PREFIX}"-* .
rm -rf "$STAGE" .build .swiftpm

git add -- "pr-${PR_NUMBER}-${SHORT_SHA}-"*
if git diff --cached --quiet; then
  echo "nothing to publish" >&2
  exit 0
fi
git commit -m "chore: e2e failure evidence for PR #${PR_NUMBER} (${SHORT_SHA})"
git push origin "$BRANCH"

raw() {
  echo "https://raw.githubusercontent.com/${REPO}/${BRANCH}/$1"
}

FAILURE_IMG="${PREFIX}-failure.png"
FAILURE_MOV="${PREFIX}-failure.mov"
HAS_FAIL_IMG=0
HAS_FAIL_MOV=0
[[ -f "$FAILURE_IMG" ]] && HAS_FAIL_IMG=1
[[ -f "$FAILURE_MOV" ]] && HAS_FAIL_MOV=1

BODY=$(printf '%s\n' \
  "<!-- e2e-core6-bot -->" \
  "### ❌ E2E メニューバー が失敗しました" \
  "" \
  "| 項目 | 内容 |" \
  "| --- | --- |" \
  "| 失敗シナリオ | \`${FAILED_SCENARIO}\` |" \
  "| エラー | \`${ERROR}\` |" \
  "| 通過済み | ${COMPLETED} |" \
  "" \
  "#### なぜ落ちたか" \
  "" \
  "${EXPLANATION}" \
  "" \
  "前回成功時に期待していた identifier:" \
  "" \
  "\`${BASELINE}\`" \
  "" \
  "#### シナリオ結果" \
  "" \
  "${SCENARIO_LIST}" \
  "" \
  "#### 失敗時の画面" \
  ""
)

if [[ "$HAS_FAIL_IMG" -eq 1 ]]; then
  URL="$(raw "$FAILURE_IMG")"
  BODY="${BODY}"$'\n'"<p><a href=\"${URL}\"><img src=\"${URL}\" alt=\"failure\" width=\"640\"></a></p>"
  BODY="${BODY}"$'\n'"<p><a href=\"${URL}\">失敗時スクリーンショット（原寸）</a></p>"$'\n'
else
  BODY="${BODY}"$'\n'"_失敗時スクリーンショットを取得できませんでした。_"$'\n'
fi

BODY="${BODY}"$'\n'"#### 失敗時の動画 / 経過"$'\n'
if [[ "$HAS_FAIL_MOV" -eq 1 ]]; then
  URL="$(raw "$FAILURE_MOV")"
  BODY="${BODY}"$'\n'"- [failure.mov を開く](${URL})"$'\n'
else
  BODY="${BODY}"$'\n'"_連続録画 (mov) は取得できませんでした。1 秒ごとの経過フレームを載せます。_"$'\n'
  BODY="${BODY}"$'\n'"<table><tr>"$'\n'
  for t in start mid end; do
    name="${PREFIX}-timeline-${t}.png"
    if [[ -f "$name" ]]; then
      URL="$(raw "$name")"
      label="$t"
      case "$t" in
        start) label="開始付近" ;;
        mid) label="中盤" ;;
        end) label="終了付近" ;;
      esac
      BODY="${BODY}<td valign=\"top\"><p><strong>${label}</strong></p>"
      BODY="${BODY}<p><a href=\"${URL}\"><img src=\"${URL}\" alt=\"${t}\" width=\"280\"></a></p></td>"
    fi
  done
  BODY="${BODY}"$'\n'"</tr></table>"$'\n'
fi

BODY="${BODY}"$'\n'"#### 正常な画面（フィクスチャ描画）"$'\n'$'\n'"<table><tr>"$'\n'
for screen in $EXPECTED_SCREENS; do
  name="${PREFIX}-expected-${screen}.png"
  if [[ -f "$name" ]]; then
    URL="$(raw "$name")"
    title="$screen"
    case "$screen" in
      popover) title="ホーム（正常）" ;;
      settings) title="設定（正常）" ;;
    esac
    BODY="${BODY}<td valign=\"top\"><p><strong>${title}</strong></p>"
    BODY="${BODY}<p><a href=\"${URL}\"><img src=\"${URL}\" alt=\"${screen}\" width=\"360\"></a></p>"
    BODY="${BODY}<p><a href=\"${URL}\">原寸を開く</a></p></td>"
  fi
done
BODY="${BODY}"$'\n'"</tr></table>"$'\n'

if [[ -n "$RUN_URL" ]]; then
  BODY="${BODY}"$'\n'"Actions ログ: ${RUN_URL}"$'\n'
fi

COMMENT_ID=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
  --jq '[.[] | select(.body | startswith("<!-- e2e-core6-bot -->"))][0].id // empty')

if [[ -n "$COMMENT_ID" ]]; then
  gh api -X PATCH "repos/${REPO}/issues/comments/${COMMENT_ID}" -f body="$BODY" > /dev/null
  echo "updated comment ${COMMENT_ID}"
else
  gh api -X POST "repos/${REPO}/issues/${PR_NUMBER}/comments" -f body="$BODY" > /dev/null
  echo "created failure comment"
fi
