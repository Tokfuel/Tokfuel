#!/usr/bin/env bash
# E2E 失敗時に証拠（スクショ・挙動 GIF・前回成功画面）を orphan ブランチへ載せ、PR コメントする。
# ui-preview.yml と同じ手法（raw.githubusercontent.com 埋め込み）。
#
# usage: bash App/Tests/E2E/comment-failure.sh
# env: GH_TOKEN, PR_NUMBER, PR_SHA, REPO, GITHUB_RUN_ID (optional)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

: "${GH_TOKEN:?}"
: "${PR_NUMBER:?}"
: "${PR_SHA:?}"
: "${REPO:?}"

OUT_DIR="$ROOT/.build/e2e"
REPORT="$OUT_DIR/report.json"
BRANCH="e2e-failure-images"
BASELINES_BRANCH="e2e-baselines"
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
eval "$(python3 - "$REPORT" "$REPO" "$PR_SHA" <<'PY'
import json, shlex, sys
r = json.load(open(sys.argv[1]))
repo = sys.argv[2]
sha = sys.argv[3]

def emit(k, v):
    print(f"{k}={shlex.quote('' if v is None else str(v))}")

def doc_path(scenario_id: str):
    # MenuBar-01-open-home → App/Tests/TestDocs/MenuBar/01-open-home.md
    if not scenario_id or "-" not in scenario_id:
        return None
    domain, rest = scenario_id.split("-", 1)
    if not domain or not rest:
        return None
    return f"App/Tests/TestDocs/{domain}/{rest}.md"

def blob_url(path: str) -> str:
    return f"https://github.com/{repo}/blob/{sha}/{path}"

def linked_id(scenario_id: str) -> str:
    path = doc_path(scenario_id)
    if path:
        return f"[`{scenario_id}`]({blob_url(path)})"
    return f"`{scenario_id}`"

failed = r.get("failedScenario") or "（不明）"
emit("FAILED_SCENARIO", failed)
emit("FAILED_SCENARIO_LINK", linked_id(failed) if failed != "（不明）" else failed)
emit("ERROR", r.get("error") or "（エラー詳細なし）")
emit("EXPLANATION", (r.get("explanation") or "").strip() or "失敗原因の説明を生成できませんでした。")
emit("BASELINE", ", ".join(r.get("baselineIdentifiers") or []))

screens = r.get("expectedScreens") or ["popover"]
emit("EXPECTED_SCREENS", " ".join(screens))
emit("PRIMARY_EXPECTED", (screens[0] if screens else "popover"))

scenarios = r.get("scenarios") or []
total = len(scenarios)
passed = sum(1 for s in scenarios if s.get("status") == "passed")
failed_n = sum(1 for s in scenarios if s.get("status") == "failed")
skipped = sum(1 for s in scenarios if s.get("status") == "skipped")
if total == 0:
    pass_pct = fail_pct = skip_pct = 0
    fail_pos = "—"
    bar = "（シナリオ情報なし）"
else:
    pass_pct = round(100 * passed / total)
    fail_pct = round(100 * failed_n / total)
    skip_pct = round(100 * skipped / total)
    fail_pos = next(
        (f"{i + 1}/{total} 本目" for i, s in enumerate(scenarios) if s.get("status") == "failed"),
        "—",
    )
    bar = "".join(
        {"passed": "🟩", "failed": "🟥", "skipped": "⬜"}.get(s.get("status"), "⬛")
        for s in scenarios
    )

coverage = (
    f"{bar}\n\n"
    f"- 通過 **{pass_pct}%**（{passed}/{total or 0}）\n"
    f"- 失敗位置 **{fail_pos}**\n"
    f"- 未検証 **{skip_pct}%**（{skipped}/{total or 0}）"
)
emit("COVERAGE", coverage)
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
[[ -f "$OUT_DIR/failure.gif" ]] && cp "$OUT_DIR/failure.gif" "$STAGE/${PREFIX}-failure.gif"
for t in start mid end; do
  [[ -f "$OUT_DIR/timeline-${t}.png" ]] && cp "$OUT_DIR/timeline-${t}.png" "$STAGE/${PREFIX}-timeline-${t}.png"
done

# 前回成功の実画面（e2e-baselines）を取得し、この PR 証拠へスナップショットする。
git fetch origin "$BASELINES_BRANCH" 2>/dev/null || true
for screen in $EXPECTED_SCREENS; do
  if git show "origin/${BASELINES_BRANCH}:${screen}.png" > "$STAGE/${PREFIX}-expected-${screen}.png" 2>/dev/null; then
    echo "copied baseline ${screen}.png from ${BASELINES_BRANCH}"
  else
    rm -f "$STAGE/${PREFIX}-expected-${screen}.png"
    echo "warning: no baseline ${screen}.png on ${BASELINES_BRANCH}" >&2
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
FAILURE_GIF="${PREFIX}-failure.gif"
HAS_FAIL_IMG=0
HAS_FAIL_MOV=0
HAS_FAIL_GIF=0
[[ -f "$FAILURE_IMG" ]] && HAS_FAIL_IMG=1
[[ -f "$FAILURE_MOV" ]] && HAS_FAIL_MOV=1
[[ -f "$FAILURE_GIF" ]] && HAS_FAIL_GIF=1

PRIMARY_TITLE="$PRIMARY_EXPECTED"
case "$PRIMARY_EXPECTED" in
  popover) PRIMARY_TITLE="ホーム" ;;
  settings) PRIMARY_TITLE="設定" ;;
esac

BODY=$(printf '%s\n' \
  "<!-- e2e-core6-bot -->" \
  "### ❌ E2E メニューバー が失敗しました" \
  "" \
  "| 項目 | 内容 |" \
  "| --- | --- |" \
  "| 失敗シナリオ | ${FAILED_SCENARIO_LINK} |" \
  "| エラー | \`${ERROR}\` |" \
  "" \
  "#### カバレッジ" \
  "" \
  "${COVERAGE}" \
  "" \
  "#### なぜ落ちたか" \
  "" \
  "${EXPLANATION}" \
  "" \
  "\`\`\`diff" \
  "- 失敗（実際）: ${ERROR}" \
  "+ 成功（期待）: ${PRIMARY_TITLE} 画面へ到達し、必須 UI が見つかること" \
  "\`\`\`" \
  "" \
  "前回成功時に期待していた identifier:" \
  "" \
  "\`${BASELINE}\`" \
  "" \
  "#### 成功 vs 失敗（比較）" \
  ""
)

BODY="${BODY}"$'\n'"<table><tr>"$'\n'
# 成功列（前回 E2E 緑の実画面）
BODY="${BODY}<td width=\"50%\" valign=\"top\" bgcolor=\"#e6f4ea\">"
BODY="${BODY}<p><strong><font color=\"#1a7f37\">🟢 成功（前回）</font></strong></p>"
exp_name="${PREFIX}-expected-${PRIMARY_EXPECTED}.png"
if [[ -f "$exp_name" ]]; then
  URL="$(raw "$exp_name")"
  BODY="${BODY}<p><a href=\"${URL}\"><img src=\"${URL}\" alt=\"last success\" width=\"360\"></a></p>"
else
  BODY="${BODY}<p>_前回成功画面なし（まだ緑の実行で baseline が載っていない）_</p>"
fi
BODY="${BODY}</td>"
# 失敗列
BODY="${BODY}<td width=\"50%\" valign=\"top\" bgcolor=\"#ffebe9\">"
BODY="${BODY}<p><strong><font color=\"#c41e3a\">🔴 失敗（今回）</font></strong></p>"
if [[ "$HAS_FAIL_IMG" -eq 1 ]]; then
  URL="$(raw "$FAILURE_IMG")"
  BODY="${BODY}<p><a href=\"${URL}\"><img src=\"${URL}\" alt=\"failure\" width=\"360\"></a></p>"
else
  BODY="${BODY}<p>_失敗時スクリーンショットなし_</p>"
fi
BODY="${BODY}</td>"
BODY="${BODY}"$'\n'"</tr></table>"$'\n'

BODY="${BODY}"$'\n'"#### 失敗時の挙動GIF"$'\n'
if [[ "$HAS_FAIL_GIF" -eq 1 ]]; then
  URL="$(raw "$FAILURE_GIF")"
  BODY="${BODY}"$'\n'"<p><a href=\"${URL}\"><img src=\"${URL}\" alt=\"failure behavior GIF\" width=\"720\"></a></p>"$'\n'
elif [[ "$HAS_FAIL_MOV" -eq 1 ]]; then
  URL="$(raw "$FAILURE_MOV")"
  BODY="${BODY}"$'\n'"<video src=\"${URL}\" width=\"720\" controls muted playsinline></video>"$'\n'
else
  BODY="${BODY}"$'\n'"_挙動 GIF を取得できませんでした。_"$'\n'
fi

if [[ -n "$RUN_URL" ]]; then
  BODY="${BODY}"$'\n'"Actions ログ: ${RUN_URL}"$'\n'
fi

# 既存の E2E ボットコメントは sticky 更新せず、hide（outdated）してから新規投稿する。
# macos の bash 3.2 でも動くよう pipe で回す。
gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" --paginate \
  --jq '.[] | select(.body | startswith("<!-- e2e-core6-bot -->")) | .node_id // empty' \
| while IFS= read -r node_id; do
  [[ -z "$node_id" ]] && continue
  if gh api graphql \
    -f query='mutation($id:ID!){minimizeComment(input:{subjectId:$id,classifier:OUTDATED}){minimizedComment{isMinimized}}}' \
    -f id="$node_id" >/dev/null; then
    echo "hid previous e2e comment ${node_id}"
  else
    echo "warning: failed to hide e2e comment ${node_id}" >&2
  fi
done

gh api -X POST "repos/${REPO}/issues/${PR_NUMBER}/comments" -f body="$BODY" > /dev/null
echo "created failure comment"
