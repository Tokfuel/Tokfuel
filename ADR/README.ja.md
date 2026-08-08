# ADR（Architecture Decision Records）

[English](README.md)

技術的な意思決定の記録を、Issue や会話に散らさずリポジトリに残す。
「なぜその形にしたか」をあとから追えるようにする。

本文は Decision / Context / Consideration / Consequences / References の
5セクションとする。置き場は git 上のこのディレクトリとする（OSS とエージェントが
同じ正本を読むため）。

全体の一覧は [`INDEX.ja.md`](INDEX.ja.md)（[English](INDEX.md)）を見る。

## ディレクトリ構成

1 件の決定 = 1 ディレクトリ。本文ファイル名は **ディレクトリ名と同じ ID-slug** にする。

```text
ADR/
  README.md / README.ja.md           # この説明
  INDEX.md / INDEX.ja.md             # 全体像（一覧）
  TEMPLATE/                          # 新規 ADR の雛形
    NNNN-slug.md / NNNN-slug.ja.md
  NNNN-slug/                         # 個別の決定
    NNNN-slug.md / NNNN-slug.ja.md
```

例: `ADR/0001-app-tree/0001-app-tree.md` と `0001-app-tree.ja.md`

| パス | 言語 |
|------|------|
| `NNNN-slug/NNNN-slug.md` | 英語 |
| `NNNN-slug/NNNN-slug.ja.md` | 日本語 |

両方が必須。内容がずれたときは **日本語（`.ja.md`）を正本**とし、英語側を合わせる。
front matter の `status` / `proposed` / `accepted` / `issue` は両ファイルで同じ値にする。

番号は既存の最大 + 1（ゼロ埋め4桁）。連番を飛ばさない。同じディレクトリに日英が
揃っていなければ未完成とみなす。`TEMPLATE/` は番号に数えない。

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

1. [`TEMPLATE/`](TEMPLATE/) を `NNNN-slug/` にコピーし、雛形の `NNNN-slug.*` を実名にリネームする
2. タイトルは動詞終わりの意思決定文にする（日本語は「〜する」、英語は concise verb phrase）
3. Decision → Context → Consideration → Consequences → References の順で書く
4. Consideration には **現状維持** を必ず含める
5. 作業文書なので日本語は常体、英語は plain technical prose
6. [`INDEX.ja.md`](INDEX.ja.md) / [`INDEX.md`](INDEX.md) に 1 行追加する
7. 起案をエージェントに任せるときは [`write-adr`](../.agents/skills/write-adr/SKILL.md) スキルを使う

大きな方針変更は、先に GitHub Issue（ラベル `ADR 🏯`）で議論し、合意した内容を ADR に落とす。
