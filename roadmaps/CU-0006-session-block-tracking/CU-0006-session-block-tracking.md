**English** · [日本語](CU-0006-session-block-tracking-ja.md)

# CU-0006 — 5-hour session-block tracking with burn rate and limit forecast

<!-- CU-METADATA -->
| Field | Value |
|---|---|
| Proposal | [CU-0006](CU-0006-session-block-tracking.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Proposal** |
| Topic | Usage & quota |
<!-- /CU-METADATA -->

## Introduction

Track the current 5-hour session block (the window Claude Code plan rate limits are enforced
over): show tokens consumed in the active block, the time until the block resets, the current
burn rate (tokens/minute), and a forecast of when the block's budget will run out. Surface the
essentials in the menu bar and fire a notification at configurable thresholds.

## Motivation

For subscription (Pro/Max) users, the thing that actually hurts is not dollar cost — it is
hitting the 5-hour rate-limit window mid-task. Every serious competitor treats this as the
core feature: ccusage has `blocks --live`, Claude Code Usage Monitor is built entirely around
burn rate and limit prediction, and CCSeva/Usage4Claude put the block percentage in the menu
bar. Our app currently answers "what did I spend?" but not "how much runway do I have right
now?" — the question a user has ten times a day. All the data needed is already in the
transcripts we scan; no new inputs are required.

## Detailed design

- **Block detection**: group transcript entries into 5-hour blocks the way ccusage does — a
  block starts at the first message after a gap and is floored to the hour; the active block
  is the one containing "now". Implemented in a pure, testable type (e.g. `SessionBlockTracker`)
  fed by `TranscriptScanner`, no python3 involved.
- **Burn rate**: tokens (and estimated cost) per minute over the active block, from the
  timestamped entries.
- **Forecast**: given a user-configured block budget (tokens or est. cost — plans don't expose
  an exact number, so this is user-tunable with sensible presets), extrapolate the depletion
  time from the burn rate and compare with the block reset time.
- **Menu bar**: optional compact text next to the icon (e.g. `42% · 2h13m`), reusing the
  budget-alert coloring convention from CU-0001.
- **Notifications**: level-rise edge with per-block re-arm, same state machine pattern as
  `BudgetMonitor` (thresholds like 70% / 90%, configurable in `SettingsView`).
- **UI**: a new "Session" section (or tab) in `PopoverView` with block progress, reset
  countdown, and burn-rate sparkline.

## Alternatives considered

**Query Anthropic's rate-limit/OAuth endpoints for the server-truth percentage.** That is
[CU-0007](../CU-0007-server-quota-readout/CU-0007-server-quota-readout.md) — a separate,
opt-in item, because it brushes the local-only ground rule. This item stays fully offline and
works with zero setup even if CU-0007 is never enabled.

**Wrap ccusage.** Rejected — would add a Node/npx dependency, violating the zero-setup and
no-new-dependencies rules. The block math is small enough to implement natively.

## Progress

- [ ] `SessionBlockTracker` (block grouping, burn rate, forecast) + unit tests.
- [ ] Popover Session UI (progress, countdown, sparkline).
- [ ] Menu-bar compact readout (opt-in setting).
- [ ] Threshold notifications reusing the `BudgetMonitor` re-arm pattern.

## References

- `Tokfuel/Sources/TranscriptScanner.swift` — the data source.
- `Tokfuel/Sources/BudgetMonitor.swift` — notification state-machine pattern to reuse.
- [ccusage blocks](https://github.com/ryoppippi/ccusage) / [Claude Code Usage Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) — prior art for block detection and burn-rate forecasting.
- [CU-0001](../CU-0001-budget-alerts/CU-0001-budget-alerts.md) — budget alerts (cost-side counterpart).
