**English** · [日本語](TF-0005-csv-export-ja.md)

# TF-0005 — CSV export

<!-- TF-METADATA -->
| Field | Value |
|---|---|
| Proposal | [TF-0005](TF-0005-csv-export.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Proposal** |
| Topic | Cost & budget |
| Origin | Internal tester feedback (2026-07): "CSV export would make this manageable for admins" |
<!-- /TF-METADATA -->

## Introduction

Export the cost report (daily / per-model / totals) as a CSV file the user saves explicitly,
so teams can aggregate members' AI spend in a spreadsheet.

## Motivation

An admin/manager keeping track of a team's AI spend today has to eyeball each member's popover.
A CSV that each member exports and submits makes that a spreadsheet problem. The same feedback
thread also floated automatic server-side collection with manager dashboards — and another
tester immediately pushed back on being monitored. Export-by-hand is the deliberate middle
ground: the data leaves the Mac **only when the user explicitly exports and shares it**.

## Detailed design

- **Entry point.** "CSV を書き出す" in the ⋯ menu (and/or a button in Settings), opening an
  `NSSavePanel`.
- **Content.** One row per day within the selected period: date, cost (USD), prompts,
  sessions, plus per-model columns. Derived from the already-decoded `RetokReport` — no new
  analysis. A header comment row records the period, export date, and app version.
- **Currency.** Amounts in USD (the internal unit); a JPY column can be added using the
  cached rate, clearly labeled with the rate date.
- **Scope.** Local file output only. No upload, no schedule, no background export.

## Alternatives considered

- **Automatic server aggregation with manager dashboards** — explicitly rejected for now:
  it contradicts the local-first ground rule, and monitoring-by-default drew immediate
  pushback from testers. If a team wants aggregation, they can collect the CSVs.
- **Clipboard-only export** — cheaper, but files fit admin workflows (attach, archive) better.
  Could ship as a bonus alongside the save panel.

## Progress

- [ ] CSV serializer over `RetokReport` (unit-tested: escaping, header, period bounds)
- [ ] ⋯ menu entry + save panel
- [ ] README note (what is exported, and that nothing is sent anywhere)

## References

- Feedback thread (internal, 2026-07-28)
