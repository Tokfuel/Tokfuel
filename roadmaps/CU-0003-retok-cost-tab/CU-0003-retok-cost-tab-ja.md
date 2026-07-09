[English](CU-0003-retok-cost-tab.md) · **日本語**

# CU-0003 — retok によるコストタブ

<!-- CU-METADATA -->
| 項目 | 値 |
|---|---|
| 提案 | [CU-0003](CU-0003-retok-cost-tab-ja.md) |
| 提案者 | [@akidon0000](https://github.com/akidon0000) |
| 状態 | **実装済み** |
| トピック | コストと予算 |
| 実装 PR | —（ローカルで実装） |
| 由来 | バックフィル（ロードマップ導入前に実装済み） |
<!-- /CU-METADATA -->

## はじめに

推定コスト、キャッシュヒット率、プロンプト単価、日次コストグラフ、モデル別内訳、高コスト
セッション、改善提案を表示する Cost タブを追加します。分析は、無改変で同梱した
[retok](https://github.com/d-date/retok)（© Daiki Matsudate, MIT）が担います。

## 動機

アプリはツールの利用量を可視化していましたが、金額については何も示していませんでした。retok は
まさにここで欲しいコスト・効率レポートを、同じトランスクリプトから計算します。ユーザーにインス
トールを求めるのではなく同梱することで、セットアップ不要の約束を保てます。自前で再実装すれば、
保守されているアナライザを重複して抱えることになります。

## 詳細設計

- `retok.py` と `locales/` を無改変で `Sources/Resources/`（SwiftPM リソース）に取り込み、
  `LICENSE-retok` と出所の記録（`README-retok.md`：上流コミット、更新手順）を添えます。
- `RetokService` が動作する `python3` を探し（Homebrew のパス、次に `/usr/bin/python3`。CLT の
  スタブが実際に動くかを確かめます）、`retok --json --days N --lang <locale>` を実行して
  `RetokReport`（合計、キャッシュヒット率、モデル別、日次、提案、上位セッション）にデコードします。
- Cost タブがレポートを描画し、メニューバーには今日のコストを表示できます。帰属表示
  （「Powered by retok © Daiki Matsudate (MIT)」）をタブ末尾と設定画面に置きます。
- python3 が無い場合はタブにエラーを表示し、アプリの他の部分には影響しません。

## 検討した代替案

**ユーザーにインストール済みの retok を要求する**（PATH に symlink）。不採用。セットアップ不要
が壊れ、マシンごとに差が出ます。

**分析を Swift で再実装する。** 不採用ではなく先送りです。
[CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis-ja.md) として
追跡しており、Mac App Store 対応への道でもあります。

## 進捗

- [x] retok + locales + ライセンスの同梱と出所ドキュメント。
- [x] `RetokService`（python3 探索、JSON デコード）+ Cost タブ UI。
- [x] アプリ内（Cost タブ末尾・設定）と両 README の帰属表示。

## 参考

- `ClaudeUsageMenubar/Sources/RetokService.swift` · `PopoverView.swift`（Cost タブ）
- [`README-retok.md`](../../ClaudeUsageMenubar/Sources/Resources/README-retok.md) — 出所と更新手順。
- [CU-0001](../CU-0001-budget-alerts/CU-0001-budget-alerts-ja.md) — このレポートの日次コストを読む予算アラート。
</content>
