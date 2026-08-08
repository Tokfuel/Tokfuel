# ADR（Architecture Decision Records）

技術的な意思決定の記録を、Issue や会話に散らさずリポジトリに残す。
「なぜその形にしたか」をあとから追えるようにする。

スタイルは Sansan Mobile ADR の5セクション構成に合わせ、置き場は git 上の
このディレクトリとする（OSS とエージェントが同じ正本を読むため）。

## 置き方

| パス | 役割 |
|------|------|
| [`TEMPLATE.md`](TEMPLATE.md) | 新規 ADR の雛形 |
| `NNNN-slug.md` | 個別の決定（4桁ゼロ埋め + kebab-case） |

番号は既存の最大 + 1。連番を飛ばさない。

## 状態（`status`）

| 値 | 意味 |
|----|------|
| `Draft` | 下書き。まだ提案として出していない |
| `Proposed` | レビュー待ち |
| `Accepted` | 採用した |
| `Rejected` | 採用しなかった（記録は残す） |
| `Deprecated` | かつて Accepted だったが、いまは使わない |
| `Superseded` | 別の ADR に置き換わった（`supersedes` / 後継を References に書く） |

## 書き方

1. [`TEMPLATE.md`](TEMPLATE.md) をコピーして `NNNN-slug.md` を作る
2. タイトルは動詞終わりの意思決定文にする（「〜する」「〜に置き換える」）
3. Decision → Context → Consideration → Consequences → References の順で書く
4. Consideration には **現状維持** を必ず含める
5. 作業文書なので日本語は常体。正本は日本語。短い English summary を Decision のあとに置いてよい
6. 起案をエージェントに任せるときは [`write-adr`](../.agents/skills/write-adr/SKILL.md) スキルを使う

大きな方針変更は、先に GitHub Issue（ラベル `ADR 🏯`）で議論し、合意した内容を ADR に落とす。
