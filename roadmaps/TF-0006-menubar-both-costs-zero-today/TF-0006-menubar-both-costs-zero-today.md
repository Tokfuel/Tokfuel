**English** · [日本語](TF-0006-menubar-both-costs-zero-today-ja.md)

# TF-0006 — Bug: "today + month" menu-bar display loses the month when today is zero

<!-- TF-METADATA -->
| Field | Value |
|---|---|
| Proposal | [TF-0006](TF-0006-menubar-both-costs-zero-today.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Proposal** |
| Topic | Bug · Menu bar |
| Origin | User report (2026-07) |
<!-- /TF-METADATA -->

## Introduction

With the menu-bar display set to "today and this month" (`bothCosts`), a day with zero usage
makes the **whole** readout fall back to the prompt count — the monthly figure disappears too,
even though it is known.

## Motivation

The month-to-date number is exactly what you still want to see on a quiet day. Losing it makes
the display feel broken and defeats the point of the combined mode.

## Detailed design

Root cause: in `AppDelegate.updateStatusTitle`, the `bothCosts` branch requires
`todayFigure()` to be non-nil. `todayFigure()` returns nil when `usageStore.todayCost` is nil —
which is the case when the retok report has no `daily` entry for today (no usage yet). The
`else if` chain then drops the month even though `monthFigure()` is available.

Fix sketch:

- Treat "no entry for today" as **$0.00**, not as missing: either make `todayCost` return `0`
  when a report is loaded but today has no row, or handle it in `todayFigure()`.
  (Keep genuine "report not loaded yet" as nil so the prompt fallback still works at startup.)
- The `bothCosts` branch should render whichever figures are available independently instead
  of requiring both.
- Add a unit test: report without a today entry → today cost formats as `$0.00` and the month
  figure is still produced.

## Alternatives considered

- Only reordering the `if let` chain (month-only fallback) — hides the real issue that a
  zero-usage day should read `$0.00`, not disappear.

## Progress

- [ ] `todayCost` semantics: loaded-but-empty day = 0
- [ ] Independent rendering in the `bothCosts` branch
- [ ] Unit test for the zero-usage day

## References

- `Tokfuel/Sources/App.swift` — `updateStatusTitle` / `todayFigure`
- `Tokfuel/Sources/UsageStore.swift` — `todayCost`
