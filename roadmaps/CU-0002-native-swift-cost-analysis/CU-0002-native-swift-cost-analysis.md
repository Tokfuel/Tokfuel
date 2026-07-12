**English** · [日本語](CU-0002-native-swift-cost-analysis-ja.md)

# CU-0002 — Reimplement cost analysis natively in Swift

<!-- CU-METADATA -->
| Field | Value |
|---|---|
| Proposal | [CU-0002](CU-0002-native-swift-cost-analysis.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Proposal** |
| Topic | Cost & budget |
| Origin | python3 dependency discussion |
<!-- /CU-METADATA -->

## Introduction

Replace the bundled [retok](https://github.com/d-date/retok) Python script — run via `python3`
as a subprocess — with a native Swift implementation of the same cost/token analysis, removing
the app's only external runtime dependency.

## Motivation

The Cost tab depends on `python3` existing on the machine (`RetokService` spawns it). Two costs
follow from that:

- **Fragility for end users.** On a Mac without the Xcode Command Line Tools, `/usr/bin/python3`
  is a stub that fails; the Cost tab then shows an error. The other tabs work, but the app's
  headline feature silently degrades.
- **It blocks the Mac App Store.** The sandbox forbids spawning an external interpreter at all,
  so as long as cost analysis runs through `python3` the app cannot be submitted to the MAS —
  only Developer ID direct distribution is possible.

retok is a single-file, standard-library-only analyzer (no third-party Python deps), so porting
its logic to Swift is tractable and would make the whole app self-contained.

## Detailed design

Port retok's `--json` computation into Swift, reading the same transcripts the existing
`TranscriptScanner` already walks:

- **Per-model token/cost model.** Mirror retok's published price table (input / output / cache
  read / cache write per MTok, per model) and its cache-hit-rate and cost-per-prompt formulas.
- **Daily aggregation.** Produce the same `daily` (date → cost) and `per_model` breakdowns the
  `RetokReport` type already decodes, so `UsageStore` / the Cost tab / `BudgetMonitor` consume
  an identical shape and need no UI change.
- **Recommendations.** Port the recommendation rules (cache-TTL re-caching, oversized contexts,
  under-delegation, retry loops, interruptions, premium-model-on-tiny-session) or, as a first
  slice, ship the numeric report and defer recommendations.
- **Keep the price table in one place** and note its provenance, since it must track retok's
  upstream table over time.

`RetokService` and the vendored `retok.py` / `locales/` would be retired once parity is proven.

## Alternatives considered

**Bundle a standalone Python runtime** (PyInstaller / freeze). Rejected — it bloats the app,
and it still cannot spawn under the MAS sandbox, so it solves neither problem cleanly.

**Keep python3 and document the requirement.** This is the status quo (fine for Developer ID +
a developer audience). This proposal is the path taken only if MAS submission or zero-dependency
robustness becomes a goal.

## Progress

- [ ] Port the price table and per-model cost math.
- [ ] Produce a `RetokReport`-shaped value natively (daily + per_model + totals).
- [ ] Reach numeric parity with retok on the same transcripts (cross-check).
- [ ] Port or defer the recommendation rules.
- [ ] Retire `RetokService` + vendored retok once parity holds.

## References

- `Tokfuel/Sources/RetokService.swift` — the subprocess this replaces.
- `Tokfuel/Sources/RetokReport` (in `RetokService.swift`) — the output shape to match.
- `Tokfuel/Sources/TranscriptScanner.swift` — the existing native JSONL reader to build on.
- [retok](https://github.com/d-date/retok) — the upstream analyzer (© Daiki Matsudate, MIT) whose logic is ported.
- [CU-0001](../CU-0001-budget-alerts/CU-0001-budget-alerts.md) — the budget feature that reads retok's daily cost; it would read the native report instead.
</content>
