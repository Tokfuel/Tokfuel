**English** · [日本語](CU-0001-budget-alerts-ja.md)

# CU-0001 — Budget alerts

<!-- CU-METADATA -->
| Field | Value |
|---|---|
| Proposal | [CU-0001](CU-0001-budget-alerts.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Implemented** |
| Topic | Cost & budget |
| Implementing PR | — (landed locally) |
<!-- /CU-METADATA -->

## Introduction

Let the user set a spending limit (USD) for a period and be warned as the period's estimated
cost approaches it: the menu-bar icon changes color and a notification fires, and the Cost tab
shows a budget progress bar.

## Motivation

The Cost tab already surfaces spend, but only when the popover is open. A user who wants to keep
monthly Claude Code spend under a target has to remember to check. A passive signal in the menu
bar — always visible — and a one-time notification when a threshold is crossed turn the app from
a thing you check into a thing that tells you.

## Detailed design

Three settings drive it (`AppSettings`): a limit in USD (`0` disables the feature), a period
origin, and a warning threshold.

- **Period origin** (`BudgetPeriod`): `rolling30` (today minus 29 days) or `calendarMonth`
  (the 1st of the current month). `BudgetMonitor.periodStart` returns the inclusive start date
  as `YYYY-MM-DD`.
- **Spend** is the sum of retok's `daily` cost entries on or after the period start. It is
  computed independently of the Cost tab's 7d/30d view by always running retok over a 32-day
  window (covers the longest calendar month), in `UsageStore.reloadBudget`.
- **Level** (`BudgetMonitor.level`): `ok` below the threshold, `warning` at/above the threshold
  and below the limit, `over` at/above the limit.
- **Menu-bar icon**: template (theme-following) at `ok`, orange at `warning`, red at `over`
  (`AppDelegate.updateStatusIcon`).
- **Notification** (`UNUserNotificationCenter`): fired only when the level *rises* above the
  last notified level. It re-arms when the period key changes (a new calendar month) or when
  spend falls back to `ok`, so a user is not re-notified every refresh. State is persisted in
  `UserDefaults`.

The Cost tab renders a progress bar colored by level, with a tick marking the warning threshold
and a remaining-budget message.

## Alternatives considered

**Notify on every refresh above the threshold.** Rejected — it would nag. A level-rise edge with
per-period re-arm gives exactly one notification per escalation.

**Drive the budget off the Cost tab's selected period (7d / 30d).** Rejected — the budget period
(rolling 30 / calendar month) is a distinct concept from the display window, and coupling them
would make the alert move when the user just changes what they're looking at.

## Progress

- [x] Settings (limit / period / threshold) in `AppSettings` + `SettingsView`.
- [x] `BudgetMonitor` (period start, level, notification re-arm).
- [x] Menu-bar icon color + Cost-tab progress bar.
- [x] Unit tests for period start, level thresholds, and the notification state machine.

## References

- `Tokfuel/Sources/BudgetMonitor.swift`
- `Tokfuel/Sources/AppSettings.swift` (`BudgetPeriod`, budget settings)
- `Tokfuel/Sources/UsageStore.swift` (`reloadBudget`, `budgetLevel`)
- `Tokfuel/Sources/App.swift` (`updateStatusIcon`, `evaluateBudget`)
- [CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis.md) — would remove the retok dependency this feature reads from.
</content>
