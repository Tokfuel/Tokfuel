[English](CU-0001-budget-alerts.md) · **日本語**

# CU-0001 — 予算アラート

<!-- CU-METADATA -->
| 項目 | 値 |
|---|---|
| 提案 | [CU-0001](CU-0001-budget-alerts-ja.md) |
| 提案者 | [@akidon0000](https://github.com/akidon0000) |
| 状態 | **実装済み** |
| トピック | コストと予算 |
| 実装 PR | —（ローカルで実装） |
<!-- /CU-METADATA -->

## はじめに

期間ごとの上限金額 (USD) を設定し、その期間の推定コストが上限に近づいたら警告します。メニュー
バーのアイコンの色が変わり、通知が飛び、Cost タブには予算の進捗バーを表示します。

## 動機

Cost タブはすでにコストを見せていますが、それはポップオーバーを開いたときだけです。月々の
Claude Code 利用額を目標内に収めたい人は、自分で確認しに行くのを覚えておく必要があります。常に
見えるメニューバーの受動的なサインと、しきい値を越えたときの一度きりの通知があれば、アプリは
「確認しに行くもの」から「向こうから知らせてくれるもの」になります。

## 詳細設計

3 つの設定（`AppSettings`）で駆動します。上限金額 (USD)（`0` で機能オフ）、期間の起点、警告の
しきい値です。

- **期間の起点**（`BudgetPeriod`）: `rolling30`（今日から 29 日前）か `calendarMonth`（今月
  1 日）。`BudgetMonitor.periodStart` が開始日を `YYYY-MM-DD`（その日を含む）で返します。
- **消費額**は、期間開始日以降の retok の `daily` コストの合計です。Cost タブの 7d/30d 表示とは
  独立に、常に 32 日ぶん（暦月の最長をカバー）で retok を実行して求めます（`UsageStore.reloadBudget`）。
- **レベル**（`BudgetMonitor.level`）: しきい値未満が `ok`、しきい値以上・上限未満が `warning`、
  上限以上が `over`。
- **メニューバーのアイコン**: `ok` はテンプレート（明暗に追従）、`warning` はオレンジ、`over` は
  赤（`AppDelegate.updateStatusIcon`）。
- **通知**（`UNUserNotificationCenter`）: 前回通知したレベルより*上がった*ときだけ送ります。
  期間キーが変わる（暦月が替わる）か、消費が `ok` に戻ると再アームするので、更新のたびに再通知
  することはありません。状態は `UserDefaults` に永続化します。

Cost タブには、レベルで色分けした進捗バーを表示し、警告しきい値の目盛りと残額のメッセージを
添えます。

## 検討した代替案

**しきい値超過を更新のたびに通知する。** 不採用。うるさくなります。レベルが上がった立ち上がり
だけを、期間ごとに再アームして拾えば、エスカレーションごとにちょうど 1 回だけ通知できます。

**Cost タブで選んだ期間（7d / 30d）で予算を測る。** 不採用。予算の期間（ローリング 30 日 / 暦
月）は表示ウィンドウとは別の概念です。両者を結び付けると、ユーザーが見る対象を変えただけで
アラートが動いてしまいます。

## 進捗

- [x] `AppSettings` + `SettingsView` の設定（上限 / 期間 / しきい値）。
- [x] `BudgetMonitor`（期間開始・レベル判定・通知の再アーム）。
- [x] メニューバーのアイコン色 + Cost タブの進捗バー。
- [x] 期間開始・レベルしきい値・通知状態機械のユニットテスト。

## 参考

- `Tokfuel/Sources/BudgetMonitor.swift`
- `Tokfuel/Sources/AppSettings.swift`（`BudgetPeriod`、予算設定）
- `Tokfuel/Sources/UsageStore.swift`（`reloadBudget`、`budgetLevel`）
- `Tokfuel/Sources/App.swift`（`updateStatusIcon`、`evaluateBudget`）
- [CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis-ja.md) — この機能が読む retok 依存を無くす提案。
</content>
