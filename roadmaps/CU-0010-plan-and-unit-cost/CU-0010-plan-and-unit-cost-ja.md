[English](CU-0010-plan-and-unit-cost.md) · **日本語**

# CU-0010 — プラン情報とトークン単価の表示

<!-- CU-METADATA -->
| 項目 | 値 |
|---|---|
| 提案 | [CU-0010](CU-0010-plan-and-unit-cost-ja.md) |
| 提案者 | [@akidon0000](https://github.com/akidon0000) |
| 状態 | **提案** |
| トピック | コストと予算 |
| 由来 | [steipete/CodexBar](https://github.com/steipete/CodexBar) |
<!-- /CU-METADATA -->

## はじめに

「いまどのプランにいるか」と「自分のトークンは実際いくらなのか」を見せます。検出した
Claude のプラン（Pro / Max 5x / Max 20x / API）、モデル別の単価表（入力 / 出力 /
キャッシュ読み取り / キャッシュ書き込みの $/Mtok）、そしてそこから導く効率指標 —
キャッシュ節約込みの実効 $/Mtok、キャッシュヒット率、サブスクリプションの API 換算額
（「今月の使用量は API なら $X だった」）— を表示する提案です。

## 動機

合計額は「いくら使ったか」には答えますが、「このプランで合っているのか」「キャッシュは
効いているのか」には答えません。CodexBar はプロバイダごとのプラン・課金サイクル表示を
備えて主要機能として挙げられており、Claude Code Usage Monitor の P90 プラン自動検出も、
自分のプランが何を意味するのか分からない人が多いからこそ存在します。サブスクリプション
ユーザーにとって、使用量アプリが出せる最も説得力のある数字は API 換算額です。毎月、
サブスクリプションの元が取れているかをその一つの数字が示します。必要な入力はすべて
ローカルに揃っています。トランスクリプトにはエントリごとのモデルとキャッシュトークン数
があり、価格は静的な表で足ります。

## 詳細設計

- **プラン検出**: ローカルにある設定・認証メタデータ（`~/.claude/.claude.json` や OAuth
  スコープのヒントなど）からプランをラベル付けします。判別できなければ「不明 — 手動で
  設定」として設定画面から選ばせます。[CU-0007](../CU-0007-server-quota-readout/CU-0007-server-quota-readout-ja.md)
  が有効なら、そのサーバー応答を正とします。
- **単価表**: 同梱の価格 JSON（[CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis-ja.md) /
  [CU-0009](../CU-0009-multi-provider-usage/CU-0009-multi-provider-usage-ja.md) と共用）から、
  モデル別の入力 / 出力 / キャッシュ読み取り / キャッシュ書き込みの $/Mtok を Cost タブの
  コンパクトな参照ビューに出します。
- **効率指標**（期間ごとにトランスクリプトから算出）:
  - *実効 $/Mtok*: 推定コスト ÷ 総トークン。モデル別と全体。
  - *キャッシュヒット率*: キャッシュ読み取り ÷（入力 + キャッシュ読み取り）と、キャッシュ
    なし入力単価と比べた節約額。
  - *API 換算額*: その期間の使用量を API 定価で買った場合の金額。サブスクリプション
    ユーザー向けの見出し統計で、プランが分かっていれば月額と並べて表示します。
- **UI**: Cost タブの先頭に「Plan」ヘッダー行（プランのバッジ + API 換算額）、展開式の
  単価表、キャッシュ節約のスタットタイルを置きます。

## 検討した代替案

**素の合計だけを出し続ける（現状維持）。** 不採用。合計を解釈可能にするのが単価経済で
あり、すでにデコード済みのデータから安く導けます。

**P90 方式の使用パターンからのプラン推定。** 後回し。ヒューリスティックで、外れたときに
かえって混乱させます。v1 はローカルメタデータ + 手動設定で足り、正確さが要るなら
CU-0007 のオプトインが真値を供給します。

## 進捗

- [ ] TBD — プラン検出 + 手動設定、単価表ビュー、効率指標、Cost タブ UI。

## 参考

- [steipete/CodexBar](https://github.com/steipete/CodexBar) — プラン・課金表示の先行事例。
- [Anthropic pricing](https://www.anthropic.com/pricing) — 単価の一次情報。
- `Tokfuel/Sources/UsageStore.swift`、`TranscriptScanner.swift` — デコード済みのトークン / キャッシュ数。
- [CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis-ja.md)、[CU-0007](../CU-0007-server-quota-readout/CU-0007-server-quota-readout-ja.md)、[CU-0009](../CU-0009-multi-provider-usage/CU-0009-multi-provider-usage-ja.md) — 共用する価格表とプラン真値。
