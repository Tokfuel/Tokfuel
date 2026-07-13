**English** · [日本語](CU-0013-local-feature-instrumentation-ja.md)

# CU-0013 — Local feature-usage instrumentation

<!-- CU-METADATA -->
| Field | Value |
|---|---|
| Proposal | [CU-0013](CU-0013-local-feature-instrumentation.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Implemented** |
| Topic | Data pipeline |
| Implementing PR | — (landed locally) |
<!-- /CU-METADATA -->

## Introduction

Have Tokfuel record its *own* usage — popover opens, tab switches, filter changes, settings
edits, notification interactions — as a local, append-only event log. The log never leaves
the Mac; it exists so later items ([CU-0014](../CU-0014-self-experiments/CU-0014-self-experiments.md)
self-experiments, [CU-0015](../CU-0015-roadmap-gardener/CU-0015-roadmap-gardener.md) roadmap
gardener) can learn which features are actually used.

## Motivation

Tokfuel analyzes Claude Code's behavior but is blind to its own: we cannot say whether the
Skills tab is ever opened or which period filter people live in. Every improvement decision
is a guess. A tiny local event log turns "I think nobody uses X" into a measurement — and it
is the substrate the automated-improvement pipeline (experiments, gardener) stands on.

## Detailed design

- **Storage**: JSONL under `~/Library/Application Support/Tokfuel/events/YYYY-MM.jsonl`,
  one file per month, pruned after 12 months. Append-only writes from a small
  `UsageEventLog` type (`@MainActor`-safe, buffered).
- **Schema** (versioned): `{"v":1,"ts":"ISO8601","event":"tab_open","meta":{"tab":"skills"}}`.
  Event names are a closed enum: `popover_open`, `tab_open`, `period_change`,
  `settings_open`, `setting_change`, `notification_shown`, and `experiment_exposure`
  (reserved for CU-0014). `notification_clicked` was dropped from v1 — it needs
  `UNUserNotificationCenterDelegate` wiring that doesn't exist yet; add both together.
- **What is never recorded**: no transcript content, no project names/paths, no costs — only
  Tokfuel UI events. The log is user-readable JSON; Settings gets a "show event log" button.
- **Privacy stance**: strictly local (ground rule 1 — nothing leaves the Mac). Enabled by
  default *because* it stays local and records only app-UI events; a Settings toggle turns it
  off and a "delete all events" button erases history.
- **Reader API**: `UsageEventLog.frequency(of:period:)` summaries for the app itself and for
  the gardener session, which reads the JSONL directly.

## Alternatives considered

**Off by default.** Rejected — the improvement pipeline needs a baseline; an opt-in log that
nobody enables measures nothing. Local-only + narrow schema + visible off-switch is the
consent story.

**Reuse the Claude transcripts as the signal.** Rejected — they show Claude Code usage, not
Tokfuel usage; the question here is which *Tokfuel* features earn their keep.

## Progress

- [x] `UsageEventLog` (write/read/prune) + unit tests (`tests/UsageEventLogTests.swift`).
- [x] Event calls at UI sites (popover, tabs, period pickers, settings, budget notification).
- [x] Settings toggle (default on) + "show log" + "delete all".

## References

- `Tokfuel/Sources/PopoverView.swift`, `SettingsView.swift`, `App.swift` — the emit sites.
- [CU-0014](../CU-0014-self-experiments/CU-0014-self-experiments.md), [CU-0015](../CU-0015-roadmap-gardener/CU-0015-roadmap-gardener.md) — the consumers.
