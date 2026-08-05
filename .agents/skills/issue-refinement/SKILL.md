---
name: issue-refinement
description: >-
  溜まったオープン Issue を棚卸しし、統合・研ぎ直し・クローズ・優先度と依存関係の再整理を
  提案する。「issue を見直して」「issue を整理して」「issue-refinement」「バックログ棚卸し」
  「重複 issue まとめて」「陳腐化した issue ないか確認して」等で使う。対話型で、提案した変更は
  ユーザーが個々に承認したものだけを `gh issue edit` / `gh issue close` / `gh issue comment` で
  反映する。無断で Issue を書き換えない。新規 Issue の起案は `ideation`、Issue の実装は
  `implementation`、次にやる 1 件を選ぶだけなら `task-select` を使う——このスキルは既存の
  オープン Issue 群そのものの健全性を上げる。
---

# Issue の棚卸し

オープンな GitHub Issue 群を通して読み、重複・スコープ・陳腐化・優先度/依存関係の 4 観点で
問題を見つけ、修正案をユーザーに提示して承認を取ってから反映する。判定するのはユーザーで、
このスキルは審判にならない。会話は日本語を基本とする。

## スコープ

- **する**：既存オープン Issue の統合提案、本文の研ぎ直し、クローズ判定、ラベル・依存関係の
  再整理。反映は `gh issue edit` / `gh issue close` / `gh issue comment` のみ。
- **しない**：新しい Issue の起案（→ [`ideation`](../ideation/SKILL.md)）、Issue の実装
  （→ [`implementation`](../implementation/SKILL.md)）、次の 1 件を選ぶだけの助言
  （→ [`task-select`](../task-select/SKILL.md)）。プロダクトコードは一切書き換えない。
- **確認なしに実行しない**：`gh issue close` や本文の書き換えは元に戻しにくい。1 件ずつ
  提示し、ユーザーが明示的に是と言ったものだけ反映する。まとめて「全部OK」と言われた場合も、
  各変更の内容は事前にリストで見せておく。

## 進め方

### 1. オープン Issue を洗う

```bash
gh issue list --repo Tokfuel/Tokfuel --state open --limit 100 \
  --json number,title,labels,body,createdAt,updatedAt,comments 2>/dev/null
gh pr list --repo Tokfuel/Tokfuel --state open --limit 20 \
  --json number,title,headRefName,body 2>/dev/null
```

進行中の PR が参照している Issue は、その旨をメモしておき、クローズ判定やスコープ変更の
対象から外す（作業を横から書き換えないため）。

### 2. 4 観点で棚卸しする

- **重複・類似の統合**：タイトルや本文の主題が重なる Issue の組を見つける。片方に寄せて
  もう片方をクローズし追記する案、または両方を残しつつ相互参照だけ足す案を判断材料として出す。
- **スコープが曖昧な Issue の研ぎ直し**：本文が粗い・古い・実装できる粒度になっていない
  Issue を、`ideation` と同じ「導入 → 詳細設計 → 進捗チェックリスト」の形に書き直す案を作る。
  既存の意図を壊さないよう、書き直し前後の差分を必ず提示する。
- **陳腐化したものの検出**：もう不要（関連機能が別 Issue で実現済み、方針転換で前提が
  崩れた、長期間動きがなく背景が失われた）に見える Issue を洗い出し、クローズ理由（何が
  変わったか、参照する後継 Issue や PR があれば番号）を添えて提案する。
- **優先度・依存関係の再整理**：本文中の `#N` 参照や AGENTS.md のグラウンドルールとの
  相性から、ブロック関係やラベルの付け替え（例：スコープが膨らみすぎて `enhancement 🚀` の
  粒度を超えている Issue に分割を提案するなど）を洗い出す。ラベルは `enhancement 🚀` /
  `bugs 🐞` / `docs ✍️` / `chore 🏠` の既存語彙を使う。

### 3. まとめて提示する

観点ごとにグルーピングし、Issue 番号・タイトル・提案内容・根拠を短く添えて一覧にする。
本文を書き換える提案は Before/After を並べる。クローズ提案は理由と後継の参照先を明記する。
不確かな判定（背景が読み切れない、意図が分からない）は「わからない」と正直に言い、
ユーザーに聞く。

### 4. 承認された分だけ反映する

```bash
# 本文更新
gh issue edit <number> --repo Tokfuel/Tokfuel --body "<新本文>" 2>/dev/null

# ラベル付け替え
gh issue edit <number> --repo Tokfuel/Tokfuel \
  --add-label "<label>" --remove-label "<label>" 2>/dev/null

# 統合（クローズ側に理由と統合先を一言残してから閉じる）
gh issue comment <number> --repo Tokfuel/Tokfuel \
  --body "#<統合先番号> に統合します。" 2>/dev/null
gh issue close <number> --repo Tokfuel/Tokfuel 2>/dev/null

# 陳腐化クローズ（理由を残してから閉じる）
gh issue comment <number> --repo Tokfuel/Tokfuel --body "<クローズ理由>" 2>/dev/null
gh issue close <number> --repo Tokfuel/Tokfuel 2>/dev/null
```

反映後は変更点を短く要約して終える（何件統合し、何件クローズし、何件本文/ラベルを直したか）。

## 参照

- [`ideation`](../ideation/SKILL.md)：新規 Issue の起案（このスキルは既存 Issue の整理専任）。
- [`implementation`](../implementation/SKILL.md)：Issue を実装して出荷する側。
- [`task-select`](../task-select/SKILL.md)：次に着手する 1 件を選ぶだけの読み取り専用スキル。
- [`japanese-tech-writing`](../japanese-tech-writing/SKILL.md)：本文を書き直すときの文章規範。
