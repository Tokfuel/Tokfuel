# Handbook — エージェント・運用ナレッジ

- 読み手: AI エージェント、実装・運用担当者
- 目的: 設計・運用の正本（[AGENTS.md](../../AGENTS.md) と連携）

## ドキュメント一覧

| ドキュメント | 用途 |
|---|---|
| [local-development.md](local-development.md) | クローン後のビルド・実行・スクリーンショット |
| [ci-and-verification.md](ci-and-verification.md) | CI とローカル検証ゲート |
| [git-workflow.md](git-workflow.md) | ブランチ、コミット、Pull Request |
| [skills.md](skills.md) | Agent Skills の正本と symlink |
| [repository-maintenance.md](repository-maintenance.md) | リポジトリ構成と変更記録の規約 |

## コードの正本

| やること | 正本 |
|---|---|
| macOS アプリ | `App/Tokfuel/`（実行体）、`App/TokfuelUI/` など SPM レイヤー |
| パッケージ定義 | [`Package.swift`](../../Package.swift) |
| サイト | [`Site/`](../../Site/)（Ignite） |
| 検証 | [`App/Tests/`](../../App/Tests/) |
| 配布スクリプト | [`Scripts/`](../../Scripts/) |
| GitHub Actions | [`.github/workflows/`](../../.github/workflows/) |

## よくある作業

| やりたいこと | コマンド / 手順 |
|---|---|
| 初回セットアップ | `bash Scripts/setup.sh` |
| ユニットテスト | `swift test` |
| リリースビルド | `swift build -c release` |
| インストールして起動 | `bash Scripts/build.sh` |
| スクリーンショット更新 | `bash Scripts/screenshot.sh` |
| Issue 起票 | [`ideation`](../../.agents/skills/ideation/SKILL.md) |
| 実装 | [`implementation`](../../.agents/skills/implementation/SKILL.md) |
| PR 作成 | [`create-pr`](../../.agents/skills/create-pr/SKILL.md) |

## ADR

[../adr/README.ja.md](../adr/README.ja.md)
