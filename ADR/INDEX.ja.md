# ADR 一覧

[English](INDEX.md)

Tokfuel のアーキテクチャ決定の全体像。詳細な書き方は [`README.ja.md`](README.ja.md)。

新規 ADR を追加・状態を変えたら、この表も同じ PR で更新する。

| 番号 | タイトル | 状態 | 要約 | リンク |
|------|----------|------|------|--------|
| 0001 | アプリ関連を App/ 配下に集約する | Accepted | 本体・Tests・TestDocs・E2E の親を `App/` に固定する | [0001-app-tree.ja.md](0001-app-tree/0001-app-tree.ja.md) |
| 0002 | SPM を feature 縦割りで分割し、並行 PR の衝突面を減らす | Proposed | 単一 target をやめ feature で割る。レイヤーは AI / 規約で担保する | [0002-feature-spm-modules.ja.md](0002-feature-spm-modules/0002-feature-spm-modules.ja.md) |

## 状態の見方

- **Accepted**: いま有効な決定
- **Proposed** / **Draft**: 検討中
- **Deprecated** / **Superseded** / **Rejected**: 履歴として残すもの
