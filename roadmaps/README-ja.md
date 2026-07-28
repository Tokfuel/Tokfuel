[English](README.md) · **日本語**

# Tokfuel — ロードマップ / バックログ

このディレクトリでは、計画中・進行中・実装済みの機能を管理します。各項目は
`TF-NNNN-<slug>/` というディレクトリで、英語ファイル `TF-NNNN-<slug>.md` と日本語ミラー
`TF-NNNN-<slug>-ja.md`（同じ ID とスラッグ）を持ちます。**TF** は *Tokfuel* の略で、
`NNNN` はゼロ埋め 4 桁の単調増加 ID です。

この規約は [bajutsu-e2e/bajutsu](https://github.com/bajutsu-e2e/bajutsu) のロードマップ方式
（`BE` プレフィックス）を、単一アプリの小さなリポジトリ向けに簡略化したものです。ID は手動で
採番し、この索引も手で保守します（CI による生成やゲートはありません）。

> このロードマップは、アプリをコスト表示専用の MVP（v0.0.x）に絞ったタイミングで
> リセットしました。旧世代の `CU-*` 項目はリセット以前の git 履歴にあります。

## 凡例

**状態** — 💡 提案 / 🚧 進行中 / ✅ 実装済み / ❄️ 保留

## ロードマップ項目の追加手順

1. **次の ID を採番する** = 既存の最大 `TF-NNNN` + 1:
   ```bash
   ls -d roadmaps/TF-*/ | sort | tail -1
   ```
   ID は恒久です — 状態が変わっても、実装が終わっても、決して振り直しません。
2. **ディレクトリと両言語のファイルを作る**
   `roadmaps/TF-NNNN-<slug>/TF-NNNN-<slug>.md`（英語）と `...-ja.md`（日本語。同じ ID とスラッグ）。
   各ファイルは **Swift-Evolution 提案形式**に従います: メタデータブロックのあと、
   `## Introduction` / `## Motivation` / `## Detailed design` / `## Alternatives considered` /
   `## Progress` / `## References`（書ける所を埋め、不明点は `TBD` と記す）。
3. **メタデータ**は `<!-- TF-METADATA -->` と `<!-- /TF-METADATA -->` に挟まれた
   `| Field | Value |` の表で、少なくとも `Proposal`（自己リンク）・`Author`・`状態`・`Topic` を持ちます。
4. **言語間の相互リンク** — 英語版ヘッダーから日本語ミラーへ、逆も同様にリンクします。
5. **この索引と [README.md](README.md) の両方に**、状態のセクションへ項目を載せます。
6. コミット前に **lint** を実行します:
   ```bash
   bash scripts/lint_roadmap.sh
   ```

## ✅ 実装済み

_まだありません（リセット後）。_

## 💡 提案

| ID | 項目 | トピック |
|---|---|---|
| [TF-0001](TF-0001-native-swift-cost-analysis/TF-0001-native-swift-cost-analysis-ja.md) | コスト分析の Swift ネイティブ再実装（python3 依存の廃止） | コストと予算 |
| [TF-0002](TF-0002-notarized-distribution/TF-0002-notarized-distribution-ja.md) | Developer ID 署名と公証による警告なしインストール | 配布 |

## 🚧 進行中

_まだありません。_

## ❄️ 保留

_まだありません。_

## 未整理のアイデア

まだ項目の形になっていない粗い思いつき。スコープが固まったら採番して昇格させます。

- プロジェクト別のコスト内訳（どのリポジトリが燃料を食っているか）。
- 5 時間セッションブロックの消費ペースと上限到達予測。
- `TranscriptScanner` にキャッシュパスを注入してユニットテスト可能にする。
- Homebrew cask（`brew install --cask tokfuel`）。
