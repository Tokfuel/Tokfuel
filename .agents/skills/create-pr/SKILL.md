---
name: create-pr
description: コミット、push、Pull Request の作成を一つの手順で行う。「プルリクエストを作成」「PRを作成」などの要求で使用する。
---

## 制約

- この skill だけでコミット、push、Pull Request 作成まで行う。別の skill へ処理を委譲しない。
- 現在のブランチが `main` の場合は作業を止める。
- ユーザーが明示的に依頼していない限り、コミット・push を行わない（「PR を作成して」とだけ言われたときは状態確認と本文作成まで）。
- 既存 PR がある場合は本文を上書きせず、ユーザーに確認する。
- PR 本文にエージェント用フッターや変更ファイル一覧を含めない。
- GitHub の branch protection 設定は変更しない。

## ワークフロー

### 1. 状態とブランチを確認する

```bash
git status
git diff --stat
git log --oneline -5
git branch --show-current
gh pr list --head "$(git branch --show-current)" --state open
```

`main` 上では作業を止める。依頼と無関係な変更をコミットに含めない。

### 2. コミットと push を行う（依頼がある場合）

変更がある場合は、論理単位でコミットする。subject は日本語可。Issue 実装 PR なら `[TF-NNNN]` 形式の PR タイトルと整合させる。

```bash
git add <files>
git commit -m "$(cat <<'EOF'
コミットメッセージ

EOF
)"
git push -u origin "$(git branch --show-current)"
```

### 3. 本文を作成する

本文は [templates/default.md](templates/default.md) を使う。[`.github/PULL_REQUEST_TEMPLATE.md`](../../../.github/PULL_REQUEST_TEMPLATE.md) と同型。

「背景」「変化」「判断」「懸念」を差分から確認できる事実に基づいて記載する。小さい変更では不要な節を削除し、変更ファイルの列挙は行わない。Issue がある場合は `Closes #<number>` を背景に含める。

### 4. PR を作成する

```bash
gh pr create \
  --title "[TF-NNNN] 日本語 / English" \
  --base main \
  --body-file <temporary-body-file>
```

タイトル・ラベル・本文の規範は [AGENTS.md](../../../AGENTS.md) の作業言語節と [git-workflow.md](../../../Docs/handbook/git-workflow.md) に従う。本文の一時ファイルは PR 作成後に削除する。

```bash
gh pr view --web
gh pr checks
```

## エラー時

- コミット失敗時は hook やテストのエラーを報告し、push しない。
- push 失敗時は原因を報告し、force push は行わない。
- PR 作成失敗時はコミットと push の状態を保持し、手動作成に必要な情報を提示する。

詳細は [Docs/handbook/git-workflow.md](../../../Docs/handbook/git-workflow.md)。
