---
name: write-adr
description: >-
  Tokfuel の Architecture Decision Record（ADR）をリポジトリ直下の ADR/ に起草する。
  「ADRを書いて」「ADR作成」「意思決定を記録して」「architecture decision record」
  「技術選定をADRに」「〜を導入する/移行するADRを書いて」等と言われたら使う。
  ライブラリ置き換え、新しい仕組みの導入、設計方針の決定など、技術的意思決定を
  Decision / Context / Consideration / Consequences / References の5セクションで、
  日本語（.ja.md）と英語（.md）の対で残す場面で発動する。単なる調査やコードレビュー、
  Issue 起案（ideation）とは別。
---

# Tokfuel ADR 起草

技術的意思決定を [`ADR/`](../../../ADR/) 配下の Markdown として起草する。
置き場と番号規則は [`ADR/README.ja.md`](../../../ADR/README.ja.md) /
[`ADR/README.md`](../../../ADR/README.md)、本文の型は
[`ADR/TEMPLATE.ja.md`](../../../ADR/TEMPLATE.ja.md) /
[`ADR/TEMPLATE.md`](../../../ADR/TEMPLATE.md) が正本。

**日英を対で書く**（`NNNN-slug.ja.md` と `NNNN-slug.md`）。ずれたときは日本語を正本とする。

会話は日本語。作業文書なので日本語本文は常体（Issue / PR の敬体とは分ける）。

## スコープ

- する: `ADR/NNNN-slug.ja.md` と `ADR/NNNN-slug.md` の起草、必要なら両ファイルの `status` 更新案
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

### 3. タイトルとファイル名

- 日本語タイトル: 動詞終わりの意思決定文（目安 20〜60 字）
- 英語タイトル: short verb-led decision sentence
- ファイル: `ADR/NNNN-slug.ja.md` と `ADR/NNNN-slug.md`
  - `NNNN` は既存最大 + 1（ゼロ埋め4桁）
  - `slug` は短い kebab-case 英語（日英で共通）

### 4. TEMPLATE の順で両言語を書く

全セクション必須。日本語を先に書き、同じ構成で英語を揃える。

1. **Decision** — 結論を太字で先に。続けて比較の要約（採用 / 不採用の一言）
2. **Context** — 背景と課題。可能なら定量
3. **Consideration** — **現状維持を必ず含む**比較表。記号だけのセルにしない
4. **Consequences** — 効果、リスクと対策、必要なら移行の粗方
5. **References** — Issue / PR / 関連 ADR / 外部リンク（両ファイルで同じリンク）

各ファイル先頭付近で、対になる言語ファイルへ相互リンクする（TEMPLATE の案内どおり）。
front matter の `status` / `proposed` / `accepted` / `issue` / `supersedes` は日英で同じ値にする。

### 5. チェックして渡す

- [ ] 日英の両ファイルがあるか
- [ ] Decision だけで決定が分かるか（両言語）
- [ ] Consideration に現状維持があるか
- [ ] 曖昧語を具体に落としたか
- [ ] グラウンドルール（ローカルオンリー、ゼロセットアップ、retok 無改変、python3 任意、新規パッケージ禁止）と衝突していないか
- [ ] front matter が日英で一致しているか

`status` の初期値は `Draft`。ユーザーが提案として出すと言ったら `Proposed` にする。
Accepted への更新は、合意または実装 PR のマージに合わせて両ファイル同時に行う。

## 文章

日本語は [`japanese-tech-writing`](../japanese-tech-writing/SKILL.md) に従い常体。
英語は plain technical prose。中黒の乱用やダッシュによる意味の詰め込みはしない。

## 参照

- [`ADR/README.ja.md`](../../../ADR/README.ja.md) / [`ADR/README.md`](../../../ADR/README.md)
- [`ADR/TEMPLATE.ja.md`](../../../ADR/TEMPLATE.ja.md) / [`ADR/TEMPLATE.md`](../../../ADR/TEMPLATE.md)
- [`ideation`](../ideation/SKILL.md) / [`implementation`](../implementation/SKILL.md)
