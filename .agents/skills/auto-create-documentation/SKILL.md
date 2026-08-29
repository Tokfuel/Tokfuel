---
name: auto-create-documentation
description: リポジトリ構成、CI、運用規約、skills を変更するとき、ADR と handbook に残すべき判断を記録する。局所的なコード修正だけには使わない。
---

# リポジトリ変更の記録

構成、CI、デプロイ、運用手順、エージェント規約を変更するときに使う。目的は、変更後のパスやコマンドだけでなく、将来も効く判断と再評価条件を残すことである。

日本語の文書は `japanese-tech-writing` の規範に従う。

## 記録先の選択

- 外部依存の採用・不採用、モジュール境界、グラウンドルールの変更、再評価条件を伴う割り切りは [`Docs/adr/`](../../../Docs/adr/) に記録する（[`write-adr`](../../write-adr/SKILL.md)）。
- 現在の正本、ディレクトリ、コマンド、ワークフロー、手順は [`Docs/handbook/`](../../../Docs/handbook/) に記録する。
- 両方に影響する変更は両方を更新する。
- 意味も運用も変えない局所的な修正や機械的な整形は記録しない。

## 作業

1. 変更前に [`Docs/handbook/README.md`](../../../Docs/handbook/README.md)、[`Docs/adr/README.ja.md`](../../../Docs/adr/README.ja.md)、[`AGENTS.md`](../../../AGENTS.md) を読み、既存の決定と正本を確認する。
2. 変更で確定した判断を特定する。未確定なら ADR に仮説として記録せず、必要な選択を利用者に確認する。
3. ADR が必要なら [`write-adr`](../../write-adr/SKILL.md) で起票する。置換する既存 ADR があれば `status` とリンクを更新する。
4. handbook には、変更後に作業者が辿るパス・コマンド・設定を記載する。新規ページは [`Docs/handbook/README.md`](../../../Docs/handbook/README.md) に追加する。
5. ADR を追加したときは [`Docs/adr/README.ja.md`](../../../Docs/adr/README.ja.md) / [`README.md`](../../../Docs/adr/README.md) の一覧表を更新する。必要に応じて `AGENTS.md` の要約も同期する。
6. 完了前に旧パス・旧コマンドを検索し、リンクを確認する。完了報告では更新した記録を挙げる。記録不要と判断した場合は理由を一文で述べる。

## 制約

- 会話に出た案を、合意なく決定として記録しない。
- コードから自明な詳細や変更履歴そのものを ADR に複製しない。
- 既存 ADR の決定を覆すときは、内容を消さず後続 ADR で置き換える。
- ドキュメント更新だけを理由に、配布ビルドやリリース操作を行わない。

詳細は [リポジトリ構成と記録](../../../Docs/handbook/repository-maintenance.md)。
