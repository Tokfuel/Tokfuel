# リポジトリ構成と記録

- 読み手: 実装・運用担当者、エージェントセッション
- 目的: 構成変更の正本と、ADR・handbook を更新する基準を定める

## 現在の構成

| 領域 | 正本 | 内容 |
|---|---|---|
| macOS アプリ | `App/` | SPM レイヤー、実行体、テスト |
| サイト | `Site/` | Ignite 静的サイト |
| 配布 | `Scripts/` | build / release / screenshot 等 |
| CI | `.github/workflows/` | 検証・プレビュー・リリース |
| ユーザー向け法務 | `Docs/legal/` | PRIVACY / TERMS（日英） |
| 意思決定 | `Docs/adr/` | 長く残る選択と理由（日英ディレクトリ） |
| 運用知識 | `Docs/handbook/` | 現在の手順と正本への入口 |
| Agent Skills | `.agents/skills/` | エージェント手順 |

## ADR に記録する変更

次の変更は [`write-adr`](../../.agents/skills/write-adr/SKILL.md) で ADR を起票する。既存決定を変えるときは旧 ADR の `status` と置換先を更新する。

- アーキテクチャ、モジュール境界、外部依存の採用・不採用
- ローカルオンリー・ゼロセットアップなどグラウンドルールの変更
- 将来の再評価条件を伴う割り切り

ファイル移動だけで意味や運用が変わらない場合は ADR を作らない。

正本の書式は [Docs/adr/README.ja.md](../adr/README.ja.md)。

## handbook に記録する変更

作業者が辿るパス、コマンド、ワークフローが変わる場合は `Docs/handbook/` を更新する。

- ビルド・検証・リリース手順
- CI のトリガーと責務
- Git / PR 運用
- Skills の追加・改名

## 変更完了前の確認

構成、運用、エージェント規約に触れた変更では、完了前に次を確認する。

1. 長期的な選択なら `Docs/adr/` を作成または更新する
2. 手順や正本が変わるなら `Docs/handbook/` を更新する
3. `Docs/handbook/README.md`、`Docs/adr/README.ja.md`、必要なら `AGENTS.md` / `README` のリンクを同期する
4. どの記録を更新したか、または更新不要と判断した理由を完了報告に含める

この確認は [`auto-create-documentation`](../../.agents/skills/auto-create-documentation/SKILL.md) スキルと AGENTS.md の指示で行う。コード内部だけの局所修正には適用しない。
