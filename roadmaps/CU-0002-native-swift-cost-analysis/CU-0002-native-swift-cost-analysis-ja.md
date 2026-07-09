[English](CU-0002-native-swift-cost-analysis.md) · **日本語**

# CU-0002 — コスト分析の Swift ネイティブ再実装

<!-- CU-METADATA -->
| 項目 | 値 |
|---|---|
| 提案 | [CU-0002](CU-0002-native-swift-cost-analysis-ja.md) |
| 提案者 | [@akidon0000](https://github.com/akidon0000) |
| 状態 | **提案** |
| トピック | コストと予算 |
| 由来 | python3 依存の議論 |
<!-- /CU-METADATA -->

## はじめに

同梱している [retok](https://github.com/d-date/retok)（`python3` でサブプロセス実行する Python
スクリプト）を、同等のコスト・トークン分析の Swift ネイティブ実装で置き換え、アプリ唯一の外部
ランタイム依存を無くします。

## 動機

Cost タブはマシンに `python3` があることに依存しています（`RetokService` がそれを起動します）。
ここから 2 つの代償が生じます。

- **エンドユーザーにとって脆い。** Xcode Command Line Tools が入っていない Mac では
  `/usr/bin/python3` は失敗するスタブで、Cost タブはエラーになります。他のタブは動きますが、
  アプリの目玉機能が黙って劣化します。
- **Mac App Store を塞ぐ。** サンドボックスは外部インタープリタの起動自体を禁じるため、コスト
  分析が `python3` を経由する限り MAS には出せず、Developer ID 直接配布しか取れません。

retok は標準ライブラリのみの単一ファイルアナライザ（サードパーティ依存なし）なので、そのロジック
を Swift に移植するのは現実的で、アプリ全体を自己完結にできます。

## 詳細設計

retok の `--json` 計算を Swift に移植し、既存の `TranscriptScanner` が走査しているのと同じ
トランスクリプトを読みます。

- **モデル別のトークン/コストモデル。** retok の公開価格表（モデルごとの input / output / cache
  read / cache write の MTok 単価）と、キャッシュヒット率・プロンプト単価の式を写します。
- **日次集計。** すでに `RetokReport` 型がデコードしている `daily`（日付 → コスト）と `per_model`
  の内訳を同じ形で produce し、`UsageStore` / Cost タブ / `BudgetMonitor` が同一の形を消費できる
  ようにして、UI 変更を不要にします。
- **推奨事項。** 推奨ルール（キャッシュ TTL 切れの再キャッシュ、巨大コンテキスト、委譲不足、
  リトライループ、割り込み、小セッションでの上位モデル）を移植します。あるいは第一段として、
  数値レポートだけ出して推奨は後回しにします。
- **価格表は一箇所にまとめ**、出所を明記します。上流 retok の表に追随し続ける必要があるためです。

パリティが確認できたら、`RetokService` と同梱の `retok.py` / `locales/` は廃止します。

## 検討した代替案

**スタンドアロンの Python ランタイムを同梱する**（PyInstaller / freeze）。不採用。アプリが肥大化
し、しかも MAS サンドボックスでは起動できないままなので、どちらの問題もきれいには解けません。

**python3 を維持して要件として明記する。** これが現状維持です（Developer ID + 開発者向けなら
十分）。本提案は、MAS への提出や依存ゼロの堅牢性が目標になったときにのみ取る道です。

## 進捗

- [ ] 価格表とモデル別コスト計算の移植。
- [ ] `RetokReport` と同じ形の値をネイティブで produce（daily + per_model + totals）。
- [ ] 同じトランスクリプトで retok と数値パリティを達成（突き合わせ）。
- [ ] 推奨ルールの移植、または後回し。
- [ ] パリティ確認後に `RetokService` + 同梱 retok を廃止。

## 参考

- `ClaudeUsageMenubar/Sources/RetokService.swift` — 置き換える対象のサブプロセス。
- `ClaudeUsageMenubar/Sources/RetokReport`（`RetokService.swift` 内）— 合わせるべき出力形。
- `ClaudeUsageMenubar/Sources/TranscriptScanner.swift` — 土台にする既存のネイティブ JSONL 読み取り。
- [retok](https://github.com/d-date/retok) — ロジックの移植元となる上流アナライザ（© Daiki Matsudate, MIT）。
- [CU-0001](../CU-0001-budget-alerts/CU-0001-budget-alerts-ja.md) — retok の日次コストを読む予算機能。ネイティブレポートを読むよう切り替わる。
</content>
