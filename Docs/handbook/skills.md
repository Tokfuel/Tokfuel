# Agent Skills

- 読み手: エージェントセッション、skills を編集する開発者
- 目的: Skills の正本・配置・編集フローを定める

## 正本

| パス | 役割 |
|---|---|
| `.agents/skills/` | Git 管理の正本。編集・コミットはここだけ |
| `.claude/skills` | 正本への symlink（Claude Code） |
| `.cursor/skills` | 正本への symlink（Cursor） |
| `.codex/skills` | 正本への symlink（Codex） |

## 収録スキル

| スキル | 用途 |
|---|---|
| `ideation` | GitHub Issue 起票 |
| `implementation` | Issue 実装から出荷まで |
| `task-select` | 次タスクの選定（読み取り専用） |
| `write-adr` | ADR 起草 |
| `japanese-tech-writing` | 日本語技術文書の規範 |
| `create-pr` | コミット・push・PR 作成 |
| `auto-create-documentation` | ADR / handbook の更新判断 |

Tokfuel 固有のワークフローは `tokfuel-{name}` プレフィックスで追加する（将来）。

## 編集フロー

1. `.agents/skills/{name}/SKILL.md` を編集する
2. feature ブランチ → PR → merge
3. 他リポジトリ（SansanMobileMetrics 等）から取り込むときは diff を確認して手動マージする（自動同期はしない）

## 参考

SansanMobileMetrics の [ADR-0002](https://github.com/sansaninc/SansanMobileMetrics/blob/main/docs/adr/0002-skills-organization.md) と同型の「正本 1 か所 + symlink」方式を採用している。
