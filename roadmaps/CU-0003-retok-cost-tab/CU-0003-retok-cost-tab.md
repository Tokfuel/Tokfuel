**English** · [日本語](CU-0003-retok-cost-tab-ja.md)

# CU-0003 — retok-powered Cost tab

<!-- CU-METADATA -->
| Field | Value |
|---|---|
| Proposal | [CU-0003](CU-0003-retok-cost-tab.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Implemented** |
| Topic | Cost & budget |
| Implementing PR | — (landed locally) |
| Origin | back-fill (shipped before the roadmap existed) |
<!-- /CU-METADATA -->

## Introduction

Add a Cost tab that shows estimated spend, cache-hit rate, cost per prompt, a daily cost chart,
a per-model breakdown, the most expensive sessions, and actionable recommendations — powered by a
bundled, unmodified copy of [retok](https://github.com/d-date/retok) (© Daiki Matsudate, MIT).

## Motivation

The app visualized tool activity but said nothing about money. retok already computes exactly the
cost/efficiency report wanted here, from the same transcripts. Bundling it (rather than requiring
the user to install it) keeps the zero-setup promise; reimplementing it would duplicate a
maintained analyzer.

## Detailed design

- `retok.py` + `locales/` are vendored unmodified into `Sources/Resources/` (SwiftPM resources)
  with `LICENSE-retok` and a provenance note (`README-retok.md`: upstream commit, update procedure).
- `RetokService` locates a working `python3` (Homebrew paths, then `/usr/bin/python3`, probing
  that the CLT shim actually runs), executes `retok --json --days N --lang <locale>`, and decodes
  into `RetokReport` (totals, cache-hit rate, per-model, daily, advice, top sessions).
- The Cost tab renders the report; the menu bar can show today's cost. Attribution ("Powered by
  retok © Daiki Matsudate (MIT)") appears at the tab's foot and in Settings.
- Without python3 the tab shows the error and the rest of the app is unaffected.

## Alternatives considered

**Require a user-installed retok** (symlink on PATH). Rejected — breaks zero-setup and drifts
per-machine.

**Reimplement the analysis in Swift.** Deferred, not rejected — tracked as
[CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis.md); it is the
path to Mac App Store eligibility.

## Progress

- [x] Vendor retok + locales + license, with provenance doc.
- [x] `RetokService` (python3 discovery, JSON decode) + Cost tab UI.
- [x] Attribution in-app (Cost tab footer, Settings) and in both READMEs.

## References

- `Tokfuel/Sources/RetokService.swift` · `PopoverView.swift` (Cost tab)
- [`README-retok.md`](../../Tokfuel/Sources/Resources/README-retok.md) — provenance & update procedure.
- [CU-0001](../CU-0001-budget-alerts/CU-0001-budget-alerts.md) — budget alerts read this report's daily costs.
</content>
