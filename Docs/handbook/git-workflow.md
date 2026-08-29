# Git / Pull Request 運用

- 読み手: 実装担当者、エージェントセッション
- 目的: ブランチ・コミット・PR の正本

## 正本

| 作業 | 正本 |
|---|---|
| Pull Request 作成 | [.agents/skills/create-pr/SKILL.md](../../.agents/skills/create-pr/SKILL.md) |
| PR 本文テンプレート（skill 用） | [.agents/skills/create-pr/templates/](../../.agents/skills/create-pr/templates/) |
| GitHub 上の PR テンプレート | [.github/PULL_REQUEST_TEMPLATE.md](../../.github/PULL_REQUEST_TEMPLATE.md) |

Claude Code、Cursor、Codex は `.agents/skills/` を参照する（`.claude/skills` 等は symlink）。

## ブランチ

- 1 トピック 1 ブランチ（`claude/<short-topic>`）
- `main` 上ではコミット・PR 作成を行わない

## コミット

- subject は 72 文字未満で変更を言い切る（日本語可）
- `feat(<scope>):` などの type プレフィックスは従来どおり使う
- body には理由（why）を書く

## Pull Request

- Issue 実装 PR のタイトル先頭は `[TF-NNNN]`、続けて `日本語 / English`
- 本文は背景 / 変化 / 判断 / 懸念（＋英語ブロック）。変更ファイルの列挙は diff に任せる
- ラベルは Issue と同様、種別＋領域を付ける

## 標準フロー

1. `create-pr` skill でブランチ・差分・既存 PR を確認する
2. 必要なコミットと push を行う
3. テンプレートに沿って PR を作成する
4. PR 前に [ci-and-verification.md](ci-and-verification.md) のゲートを満たす

Issue 起票は [`ideation`](../../.agents/skills/ideation/SKILL.md)、実装は [`implementation`](../../.agents/skills/implementation/SKILL.md) を使う。
