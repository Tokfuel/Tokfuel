**English** · [日本語](TF-0001-native-swift-cost-analysis-ja.md)

# TF-0001 — Reimplement cost analysis natively in Swift

<!-- TF-METADATA -->
| Field | Value |
|---|---|
| Proposal | [TF-0001](TF-0001-native-swift-cost-analysis.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Proposal** |
| Topic | Cost & budget |
| Origin | python3 dependency discussion (formerly CU-0002) |
<!-- /TF-METADATA -->

## Introduction

Replace the bundled [retok](https://github.com/d-date/retok) Python script — run via `python3`
as a subprocess — with a native Swift implementation of the same cost/token analysis, removing
the app's only external runtime dependency.

## Motivation

The whole app now *is* the cost view, so its headline feature depends on `python3` existing on
the machine (`RetokService` spawns it):

- **Fragility for end users.** On a Mac without the Xcode Command Line Tools, `/usr/bin/python3`
  is a stub that fails; the app then shows an error instead of any cost.
- **It blocks the Mac App Store.** The sandbox forbids spawning an external interpreter, so as
  long as cost analysis runs through `python3` the app cannot be submitted to the MAS.
- **Latency.** Each period switch re-runs the interpreter over the transcripts (seconds), which
  is why the chart needs a loading overlay at all.

retok is a single-file, standard-library-only analyzer, so porting its logic to Swift is
tractable and would make the whole app self-contained.

## Detailed design

Port retok's `--json` computation into Swift, reading the same transcripts the existing
`TranscriptScanner` already walks:

- **Per-model token/cost model.** Mirror retok's price table (input / output / cache read /
  cache write per MTok, per model) and its cache-hit-rate and cost-per-prompt formulas.
- **Same report shape.** Produce the `daily` / `per_model` / `totals` breakdowns the existing
  `RetokReport` type decodes, so `UsageStore`, the popover, and `BudgetMonitor` need no change.
- **Recommendations.** Port the advice rules, or as a first slice ship the numeric report and
  defer recommendations.
- **Keep the price table in one place** and note its provenance, since it must track retok's
  upstream table over time.

Keep the vendored retok and its attribution until the port reaches parity; retire the
subprocess path (and the `python3` requirement in the README) in the same PR that flips the
default.

## Alternatives considered

- **Keep shelling out to python3** — status quo; keeps the fragility and MAS blocker.
- **Bundle a Python runtime** — enormous app-size cost for a menu-bar utility.

## Progress

- [ ] Price table + cost formulas in Swift, with unit tests against retok's output
- [ ] Daily / per-model aggregation matching `RetokReport`
- [ ] Advice rules (or explicit deferral)
- [ ] Flip `RetokService` to the native path; drop the python3 requirement from the README

## References

- [retok](https://github.com/d-date/retok) — © Daiki Matsudate, MIT
- [README-retok.md](../../Tokfuel/Sources/Resources/README-retok.md) — vendored provenance
