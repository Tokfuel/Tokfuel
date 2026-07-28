[English](TF-0001-native-swift-cost-analysis.md) · **日本語**

# TF-0001 — コスト分析の Swift ネイティブ再実装

<!-- TF-METADATA -->
| Field | Value |
|---|---|
| Proposal | [TF-0001](TF-0001-native-swift-cost-analysis-ja.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| 状態 | **提案** |
| Topic | コストと予算 |
| Origin | python3 依存の議論（旧 CU-0002） |
<!-- /TF-METADATA -->

## Introduction

`python3` のサブプロセスとして実行している同梱の [retok](https://github.com/d-date/retok)
（Python スクリプト）を、同じコスト・トークン分析の Swift ネイティブ実装に置き換え、
アプリ唯一の外部ランタイム依存をなくします。

## Motivation

アプリ全体がコスト表示そのものになった今、看板機能がマシン上の `python3` の有無に
依存しています（`RetokService` が spawn します）。

- **エンドユーザーにとって脆い。** Xcode Command Line Tools が無い Mac では
  `/usr/bin/python3` はスタブで失敗し、アプリはコストの代わりにエラーを表示します。
- **Mac App Store を塞ぐ。** サンドボックスは外部インタプリタの起動を禁止しており、
  `python3` 経由である限り MAS には出せません。
- **レイテンシ。** 期間を切り替えるたびにインタプリタがトランスクリプトを再解析（数秒）
  するため、グラフにローディング表示が必要になっています。

retok は標準ライブラリのみの単一ファイル解析器なので、Swift への移植は現実的で、
アプリを完全に自己完結にできます。

## Detailed design

retok の `--json` 計算を Swift に移植し、既存の `TranscriptScanner` が走査しているのと
同じトランスクリプトを読みます。

- **モデル別のトークン・コストモデル。** retok の価格表（モデルごとの input / output /
  cache read / cache write 単価）とキャッシュヒット率・プロンプト単価の式を踏襲します。
- **レポートの形は同じに。** 既存の `RetokReport` 型がデコードする `daily` / `per_model` /
  `totals` を生成し、`UsageStore`・ポップオーバー・`BudgetMonitor` は無変更で済ませます。
- **改善提案。** アドバイスのルールも移植するか、第一段では数値レポートのみ出して
  提案は保留します。
- **価格表は一箇所に**まとめ、出典を明記します（上流 retok の表に追随する必要があるため）。

移植がパリティに達するまで同梱 retok と帰属表示は維持し、デフォルトを切り替える PR で
サブプロセス経路（と README の python3 要件）を退役させます。

## Alternatives considered

- **python3 への外部実行を続ける** — 現状維持。脆さと MAS の障壁が残ります。
- **Python ランタイムを同梱する** — メニューバーユーティリティにはアプリサイズが過大です。

## Progress

- [ ] 価格表とコスト式の Swift 実装（retok の出力と突き合わせるユニットテスト付き）
- [ ] `RetokReport` に一致する日次・モデル別集計
- [ ] アドバイスルール（または明示的な保留）
- [ ] `RetokService` をネイティブ経路に切り替え、README から python3 要件を削除

## References

- [retok](https://github.com/d-date/retok) — © Daiki Matsudate, MIT
- [README-retok.md](../../Tokfuel/Sources/Resources/README-retok.md) — 同梱の出所記録
