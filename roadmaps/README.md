**English** · [日本語](README-ja.md)

# Tokfuel — roadmap / backlog

This directory tracks features planned, in progress, and shipped. Each item is a directory
`TF-NNNN-<slug>/` holding an English file `TF-NNNN-<slug>.md` and its Japanese mirror
`TF-NNNN-<slug>-ja.md` (same ID and slug). **TF** stands for *Tokfuel* and `NNNN` is a
zero-padded, 4-digit, monotonically increasing ID.

The convention is adapted from [bajutsu-e2e/bajutsu](https://github.com/bajutsu-e2e/bajutsu)'s
roadmap system (which uses the `BE` prefix), simplified for a small single-app repo: IDs are
allocated by hand, and this index is hand-maintained (no CI generation or gate).

> The roadmap was reset when the app pivoted to a cost-only MVP (v0.0.x). The retired `CU-*`
> generation lives in git history before that reset.

## Legend

**Status** — 💡 Proposal / 🚧 In progress / ✅ Implemented / ❄️ Deferred

## Adding a roadmap item

1. **Allocate the next ID** = highest existing `TF-NNNN` + 1:
   ```bash
   ls -d roadmaps/TF-*/ | sort | tail -1
   ```
   IDs are permanent — never renumber an item, not when its status changes, not when it ships.
2. **Create the directory and both language files**
   `roadmaps/TF-NNNN-<slug>/TF-NNNN-<slug>.md` (English) and `...-ja.md` (Japanese, same ID & slug).
   Each file follows the **Swift-Evolution proposal format**: a metadata block, then
   `## Introduction` / `## Motivation` / `## Detailed design` / `## Alternatives considered` /
   `## Progress` / `## References` (fill what you can; mark unknowns `TBD`).
3. **Metadata** is a fenced `| Field | Value |` table between `<!-- TF-METADATA -->` and
   `<!-- /TF-METADATA -->`, with at least `Proposal` (self link), `Author`, `Status`, `Topic`.
4. **Cross-link the languages** — the EN header links the JA mirror and vice versa.
5. **List the item in both this index and [README-ja.md](README-ja.md)** under its status section.
6. **Lint** before committing:
   ```bash
   bash scripts/lint_roadmap.sh
   ```

## ✅ Implemented

_None yet (post-reset)._

## 💡 Proposals

| ID | Item | Topic |
|---|---|---|
| [TF-0001](TF-0001-native-swift-cost-analysis/TF-0001-native-swift-cost-analysis.md) | Reimplement cost analysis natively in Swift (drop the python3 dependency) | Cost & budget |
| [TF-0002](TF-0002-notarized-distribution/TF-0002-notarized-distribution.md) | Developer ID signing & notarization for warning-free installs | Distribution |
| [TF-0003](TF-0003-menubar-budget-gauge/TF-0003-menubar-budget-gauge.md) | Menu-bar budget gauge (ring chart) | Menu bar & UX |
| [TF-0004](TF-0004-cursor-usage/TF-0004-cursor-usage.md) | Collect Cursor usage data | Providers |
| [TF-0005](TF-0005-csv-export/TF-0005-csv-export.md) | CSV export for team/admin aggregation | Cost & budget |
| [TF-0006](TF-0006-menubar-both-costs-zero-today/TF-0006-menubar-both-costs-zero-today.md) | Bug: "today + month" display loses the month when today is zero | Bug · Menu bar |

## 🚧 In progress

_None yet._

## ❄️ Deferred

_None yet._

## Unsorted ideas

Rough thoughts not yet shaped into an item. Promote to a numbered item once the scope is clear.

- Per-project cost breakdown (which repo is burning the fuel).
- 5-hour session-block tracking with burn rate and limit forecast.
- Inject the transcript-cache path into `TranscriptScanner` so it becomes unit-testable.
- Homebrew cask for `brew install --cask tokfuel`.
