---
name: write-adr
description: >-
  Tokfuel の Architecture Decision Record（ADR）を `Docs/adr/` に起草する。
  「ADRを書いて」「ADR作成」「意思決定を記録して」「architecture decision record」
  「技術選定をADRに」「〜を導入する/移行するADRを書いて」等と言われたら使う。
  ライブラリ置き換え、新しい仕組みの導入、設計方針の決定など、技術的意思決定を
  Decision / Context / Consideration / Consequences / References の5セクションで、
  Docs/adr/NNNN-slug/NNNN-slug(.ja).md として残す場面で発動する。単なる調査や
  コードレビュー、Issue 起案（ideation）とは別。
---

# Tokfuel ADR 起草

技術的意思決定を [`Docs/adr/`](../../../Docs/adr/) 配下に起草する。
置き場・番号規則・一覧は [`Docs/adr/README.ja.md`](../../../Docs/adr/README.ja.md) /
[`Docs/adr/README.md`](../../../Docs/adr/README.md)、本文の型は
[`Docs/adr/TEMPLATE/`](../../../Docs/adr/TEMPLATE/)。

**1 決定 = 1 ディレクトリ**。本文はディレクトリ名と同じ ID-slug ファイルにする
（例: `Docs/adr/0001-app-tree/0001-app-tree.ja.md` と `0001-app-tree.md`）。
ずれたときは日本語（`.ja.md`）を正本とする。新規・状態変更のときは README の一覧表も更新する。

会話は日本語。作業文書なので日本語本文は常体（Issue / PR の敬体とは分ける）。

## スコープ

- する: `Docs/adr/NNNN-slug/NNNN-slug.ja.md` と `NNNN-slug.md` の起草、両 front matter の
  `status` 更新、README 日英の一覧表への行追加・更新
- しない: ユーザーが求めない限りの PR 作成、プロダクトコードの実装（実装は
  [`implementation`](../implementation/SKILL.md)）、Issue だけの起案（それは
  [`ideation`](../ideation/SKILL.md)）

大きな方針は、先に Issue（ラベル `ADR 🏯`）があるとよい。Issue が無ければ起票を提案する。

## 進め方

### 1. タイプを見極める

- **A. 置き換え型**: 既存の X を Y に移す
- **B. 新規導入型**: 新しい仕組みを入れる
- **C. 設計方針型**: モジュール分割や依存の向きなど、方針を決める

### 2. 一次情報を集める

推測で埋めない。コード（件数・行数・依存）、関連 Issue / PR / 既存 ADR、ユーザーへの確認から集める。
定量が取れない箇所は「（要確認）」と明示する。

### 3. タイトルと ID-slug

- 日本語タイトル: 動詞終わりの意思決定文（目安 20〜60 字）
- 英語タイトル: short verb-led decision sentence
- ディレクトリと本文ファイル: `Docs/adr/NNNN-slug/` + `NNNN-slug.md` / `NNNN-slug.ja.md`
  - `NNNN` は既存最大 + 1（ゼロ埋め4桁）。`TEMPLATE/` は番号に数えない
  - `slug` は短い kebab-case 英語

### 4. TEMPLATE をコピーして両言語を書く

```bash
cp -R Docs/adr/TEMPLATE "Docs/adr/0001-app-tree"
mv Docs/adr/0001-app-tree/NNNN-slug.md Docs/adr/0001-app-tree/0001-app-tree.md
mv Docs/adr/0001-app-tree/NNNN-slug.ja.md Docs/adr/0001-app-tree/0001-app-tree.ja.md
```

雛形の `NNNN-slug.*` を、ディレクトリと同じ実 ID-slug へリネームする。

全セクション必須。日本語を先に書き、同じ構成で英語を揃える。

1. **Decision** — 結論を太字で先に。続けて比較の要約
2. **Context** — 背景と課題。可能なら定量
3. **Consideration** — **現状維持を必ず含む**比較表。記号だけのセルにしない
4. **Consequences** — 効果、リスクと対策
5. **References** — Issue / PR / 関連 ADR / 外部リンク（両ファイルで同じリンク）

front matter の `status` / `proposed` / `accepted` / `issue` / `supersedes` は日英で同じ値にする。

### 5. README の一覧を更新する

[`README.ja.md`](../../../Docs/adr/README.ja.md) と [`README.md`](../../../Docs/adr/README.md) の
一覧表に、番号・タイトル・状態・1行要約・本文へのリンクを追加（または状態を更新）する。

### 6. チェックして渡す

- [ ] `NNNN-slug/NNNN-slug.ja.md` と `NNNN-slug.md` があるか
- [ ] README 日英の一覧表が更新されているか
- [ ] Decision だけで決定が分かるか（両言語）
- [ ] Consideration に現状維持があるか
- [ ] 曖昧語を具体に落としたか
- [ ] グラウンドルールと衝突していないか
- [ ] front matter が日英で一致しているか

`status` の初期値は `Draft`。ユーザーが提案として出すと言ったら `Proposed` にする。
Accepted への更新は、合意または実装 PR のマージに合わせて本文と README 一覧を同時に直す。

## 文章

日本語は [`japanese-tech-writing`](../japanese-tech-writing/SKILL.md) に従い常体。
英語は plain technical prose。中黒の乱用やダッシュによる意味の詰め込みはしない。

## 参照

- [`Docs/adr/README.ja.md`](../../../Docs/adr/README.ja.md) / [`Docs/adr/README.md`](../../../Docs/adr/README.md)
- [`Docs/adr/TEMPLATE/`](../../../Docs/adr/TEMPLATE/)
- [`ideation`](../ideation/SKILL.md) / [`implementation`](../implementation/SKILL.md)
