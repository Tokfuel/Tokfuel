[English](CU-0013-local-feature-instrumentation.md) · **日本語**

# CU-0013 — アプリ自身の利用イベント記録（ローカル限定）

<!-- CU-METADATA -->
| 項目 | 値 |
|---|---|
| 提案 | [CU-0013](CU-0013-local-feature-instrumentation-ja.md) |
| 提案者 | [@akidon0000](https://github.com/akidon0000) |
| 状態 | **提案** |
| トピック | データパイプライン |
<!-- /CU-METADATA -->

## はじめに

Tokfuel に*自分自身*の利用 — ポップオーバーを開いた、タブを切り替えた、フィルタを変えた、
設定を触った、通知に反応した — をローカルの追記専用イベントログとして記録させます。ログは
Mac の外に出ません。後続の [CU-0014](../CU-0014-self-experiments/CU-0014-self-experiments-ja.md)
（自己実験）と [CU-0015](../CU-0015-roadmap-gardener/CU-0015-roadmap-gardener-ja.md)
（ロードマップの自動起票）が「どの機能が実際に使われているか」を学ぶための土台です。

## 動機

Tokfuel は Claude Code の挙動を分析しますが、自分の挙動には盲目です。Skills タブが一度でも
開かれているのか、どの期間フィルタが常用されているのか、いまは何も言えません。改善の判断が
すべて勘になっています。小さなローカルイベントログがあれば「X は誰も使っていない気がする」
が計測に変わり、実験と自動起票のパイプラインが立つ基盤になります。

## 詳細設計

- **保存先**: `~/Library/Application Support/Tokfuel/events/YYYY-MM.jsonl`（月 1 ファイル、
  12 か月で削除）。小さな `UsageEventLog` 型（`@MainActor` 安全・バッファリングあり）から
  追記のみ行います。
- **スキーマ**（バージョンつき）: `{"v":1,"ts":"ISO8601","event":"tab_open","meta":{"tab":"skills"}}`。
  イベント名は閉じた列挙（まず 10 個ほど）: `popover_open`、`tab_open`、`period_change`、
  `settings_open`、`setting_change`、`notification_shown`、`notification_clicked`、
  `experiment_exposure`（CU-0014 用の予約）。
- **決して記録しないもの**: トランスクリプトの内容、プロジェクト名・パス、コスト。記録する
  のは Tokfuel の UI イベントだけです。ログは人間が読める JSON で、設定画面に「イベントログ
  を表示」ボタンを付けます。
- **プライバシー方針**: 厳密にローカルです（原則 1 — データは Mac から出ません）。ローカル
  に留まり UI イベントしか記録しないからこそデフォルト有効とし、設定でオフにでき、「全イベント
  を削除」ボタンで履歴を消せます。
- **読み出し API**: アプリ自身と gardener セッション向けに `UsageEventLog.frequency(of:period:)`
  の集計を提供します（gardener は JSONL を直接読みます）。

## 検討した代替案

**デフォルト無効。** 不採用。改善パイプラインにはベースラインが必要で、誰も有効にしない
オプトインのログは何も計測しません。ローカル限定・狭いスキーマ・見えるオフスイッチが同意の
形です。

**Claude のトランスクリプトを信号として流用。** 不採用。あれが示すのは Claude Code の利用
であって Tokfuel の利用ではありません。ここで問うのは *Tokfuel の*どの機能が働いているかです。

## 進捗

- [ ] TBD — `UsageEventLog`（書き込み / 読み出し / 削除）とユニットテスト、UI 各所への
  記録呼び出し、設定のトグル + ビューア + 削除。

## 参考

- `Tokfuel/Sources/PopoverView.swift`、`SettingsView.swift`、`App.swift` — イベントの発生源。
- [CU-0014](../CU-0014-self-experiments/CU-0014-self-experiments-ja.md)、[CU-0015](../CU-0015-roadmap-gardener/CU-0015-roadmap-gardener-ja.md) — この記録の利用者。
