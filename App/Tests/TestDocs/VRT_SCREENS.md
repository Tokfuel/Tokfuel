# VRT 画面名 ↔ TestDocs 観点 ID

正本の機械可読マップは `App/Tests/UnitTests/VRTScreenMap.swift` です。
画面を足すときは `ScreenshotRenderer.screenNames`・この表・シナリオ MD の VRT 完了条件を同じ PR で更新します。

| 画面名（スナップショット / ui-preview） | TestDocs 観点 ID |
| --- | --- |
| `about` | `Settings-32-about-window` |
| `analytics-consent` | `Settings-33-analytics-consent-first-run` |
| `budget-alert` | `Budget-10-alert-window-warning` |
| `popover` | `MenuBar-01-open-home`, `Settings-09-cost-source-side-by-side` |
| `popover-advice` | `Cost-20-advice-section` |
| `popover-advice-expanded` | `Cost-21-advice-expand` |
| `popover-claude-only` | `Settings-06-cost-source-claude-only` |
| `popover-combined` | `Settings-05-cost-source-combined` |
| `popover-cumulative` | `Cost-01-chart-style` |
| `popover-cursor-degraded` | `Cursor-11-degraded-warning` |
| `popover-cursor-signin` | `Cursor-12-sign-in-open-app` |
| `popover-jpy` | `Cost-12-jpy-formatting` |
| `popover-light` | `Settings-04-appearance` |
| `popover-more-menu` | `MenuBar-01-open-home` |
| `popover-period-month` | `Cost-02-period-switch` |
| `popover-period-today` | `Cost-02-period-switch` |
| `popover-period-week` | `Cost-02-period-switch` |
| `popover-period-year` | `Cost-02-period-switch` |
| `popover-scrolled` | `Cost-20-advice-section` |
| `popover-sessions` | `Cost-18-top-sessions` |
| `popover-update` | `MenuBar-29-update-button-offer` |
| `settings` | `Settings-01-open` |
| `settings-advanced` | `Settings-26-advanced-disclosure` |
| `settings-claude-only` | `Settings-06-cost-source-claude-only` |
| `settings-debug` | `Settings-37-debug-disclosure` |
| `settings-jpy` | `Settings-36-currency-jpy-budget-unit` |

## 観点 ID → 画面名

| TestDocs 観点 ID | 画面名 |
| --- | --- |
| `Budget-10-alert-window-warning` | `budget-alert` |
| `Cost-01-chart-style` | `popover-cumulative` |
| `Cost-02-period-switch` | `popover-period-month`, `popover-period-today`, `popover-period-week`, `popover-period-year` |
| `Cost-12-jpy-formatting` | `popover-jpy` |
| `Cost-18-top-sessions` | `popover-sessions` |
| `Cost-20-advice-section` | `popover-advice`, `popover-scrolled` |
| `Cost-21-advice-expand` | `popover-advice-expanded` |
| `Cursor-11-degraded-warning` | `popover-cursor-degraded` |
| `Cursor-12-sign-in-open-app` | `popover-cursor-signin` |
| `MenuBar-01-open-home` | `popover`, `popover-more-menu` |
| `MenuBar-29-update-button-offer` | `popover-update` |
| `Settings-01-open` | `settings` |
| `Settings-04-appearance` | `popover-light` |
| `Settings-05-cost-source-combined` | `popover-combined` |
| `Settings-06-cost-source-claude-only` | `popover-claude-only`, `settings-claude-only` |
| `Settings-09-cost-source-side-by-side` | `popover` |
| `Settings-26-advanced-disclosure` | `settings-advanced` |
| `Settings-32-about-window` | `about` |
| `Settings-33-analytics-consent-first-run` | `analytics-consent` |
| `Settings-36-currency-jpy-budget-unit` | `settings-jpy` |
| `Settings-37-debug-disclosure` | `settings-debug` |
