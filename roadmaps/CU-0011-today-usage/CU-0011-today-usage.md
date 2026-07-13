**English** · [日本語](CU-0011-today-usage-ja.md)

# CU-0011 — "Today" usage view

<!-- CU-METADATA -->
| Field | Value |
|---|---|
| Proposal | [CU-0011](CU-0011-today-usage.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Implemented** |
| Topic | Settings & UX |
| Implementing PR | — (landed locally) |
<!-- /CU-METADATA -->

## Introduction

Make *today* a first-class time range everywhere usage is shown: today's cost, tokens, and
tool activity at the top of the popover, and a `today` option in every period selector
(Cost tab currently starts at 7d; the Tools tab has no filter at all).

## Motivation

"What have I used *today*?" is the most frequent question a menu-bar usage app gets asked,
and every competitor answers it first — ccusage's default report is daily, CCSeva and the
Raycast extension lead with today's numbers. Tokfuel currently opens on 7d/30d aggregates, so
the most common glance requires mental subtraction. The transcripts are already grouped by
day in the scan pipeline; this is UI surface, not new data.

## Detailed design

- **Period model**: add `today` to the shared period selection (alongside 7d / 30d), defined
  as the local calendar day. This absorbs the "time-range filter for the Tools tab" entry
  from Unsorted ideas: the same selector (today / 7d / 30d / all) applies to the Tools tab.
- **Cost tab**: `today` option in the existing picker; budget logic (CU-0001) is unaffected
  (its period is deliberately independent).
- **Header summary**: a compact "Today" line at the top of `PopoverView` — est. cost, prompts,
  session count (tokens are not aggregated per-day yet) — visible regardless of the selected
  tab or period.
- **Persistence**: remember the last-selected period in `AppSettings`.
- Plays with [CU-0006](../CU-0006-session-block-tracking/CU-0006-session-block-tracking.md)
  (block = intraday runway) and [CU-0008](../CU-0008-project-cost-breakdown/CU-0008-project-cost-breakdown.md)
  (whose time filter should be this same control).

## Alternatives considered

**Menu-bar text showing today's cost.** Deferred — the menu-bar slot is contested (CU-0006
wants it for block runway); a Settings choice of *what* the menu-bar shows can come later.

**"Today" as midnight-UTC.** Rejected — users think in local days; use the local calendar day.

## Progress

- [x] `PeriodFilter` (today / 7d / 30d / all) + unit tests (`tests/PeriodFilterTests.swift`).
- [x] Tools-tab filter (repos / genres / rankings / summary cards re-aggregate; daily chart and
  skill inventory intentionally stay all-time).
- [x] Cost-tab `Today` option (retok over 1 day).
- [x] Header "Today" summary line (cost · prompts · sessions) on every tab.
- [x] Last-selected periods persisted (`reportDays` / `toolsPeriod` in UserDefaults).

## References

- `Tokfuel/Sources/PopoverView.swift`, `UsageStore.swift`, `AppSettings.swift`.
- Roadmap Unsorted ideas — the Tools-tab time-range bullet this item absorbs.
- [ccusage](https://github.com/ryoppippi/ccusage) daily-first reports — prior art.
