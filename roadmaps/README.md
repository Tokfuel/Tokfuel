**English** · [日本語](README-ja.md)

# Tokfuel — roadmap / backlog

This directory tracks features planned, in progress, and shipped. Each item is a directory
`CU-NNNN-<slug>/` holding an English file `CU-NNNN-<slug>.md` and its Japanese mirror
`CU-NNNN-<slug>-ja.md` (same ID and slug). **CU** stands for *Claude Usage* (the app's original name, kept for ID stability) and `NNNN` is a
zero-padded, 4-digit, monotonically increasing ID.

The convention is adapted from [bajutsu-e2e/bajutsu](https://github.com/bajutsu-e2e/bajutsu)'s
roadmap system (which uses the `BE` prefix), simplified for a small single-app repo: IDs are
allocated by hand, and this index is hand-maintained (no CI generation or gate).

## Legend

**Status** — 💡 Proposal / 🚧 In progress / ✅ Implemented / ❄️ Deferred

## Adding a roadmap item

1. **Allocate the next ID** = highest existing `CU-NNNN` + 1:
   ```bash
   ls -d roadmaps/CU-*/ | sort | tail -1
   ```
   IDs are permanent — never renumber an item, not when its status changes, not when it ships.
2. **Create the directory and both language files**
   `roadmaps/CU-NNNN-<slug>/CU-NNNN-<slug>.md` (English) and `...-ja.md` (Japanese, same ID & slug).
   Each file follows the **Swift-Evolution proposal format**: a metadata block, then
   `## Introduction` / `## Motivation` / `## Detailed design` / `## Alternatives considered` /
   `## Progress` / `## References` (fill what you can; mark unknowns `TBD`).
3. **Metadata** is a fenced `| Field | Value |` table between `<!-- CU-METADATA -->` and
   `<!-- /CU-METADATA -->`, holding `Proposal`, `Author` (GitHub handle), `Status`, `Topic`
   (plus `Implementing PR` once shipped, `Origin` when applicable). The Japanese mirror uses
   `提案` / `提案者` / `状態` / `トピック` / `実装 PR` / `由来`.
4. **Update the tables below** by hand when you add or promote an item.

Write the Japanese file (`*-ja.md`) in **敬体 (polite ですます調)** per the
[`japanese-tech-writing`](../.claude/skills/japanese-tech-writing/SKILL.md) skill — natural
Japanese, not a literal translation of the English.

The roadmap workflow is driven by skills under [`.claude/skills/`](../.claude/skills/):
[`ideation`](../.claude/skills/ideation/SKILL.md) (author a proposal),
[`implement-cu`](../.claude/skills/implement-cu/SKILL.md) (ship a numbered item),
[`propose-and-build`](../.claude/skills/propose-and-build/SKILL.md) (do both),
[`roadmap-filter`](../.claude/skills/roadmap-filter/SKILL.md) (survey by status),
[`task-select`](../.claude/skills/task-select/SKILL.md) (pick the next item).

---

## ✅ Implemented

| ID | Item | Topic |
|---|---|---|
| [CU-0001](CU-0001-budget-alerts/CU-0001-budget-alerts.md) | Budget alerts (menu-bar color + notification) | Cost & budget |
| [CU-0003](CU-0003-retok-cost-tab/CU-0003-retok-cost-tab.md) | retok-powered Cost tab | Cost & budget |
| [CU-0004](CU-0004-zero-setup-transcript-scanning/CU-0004-zero-setup-transcript-scanning.md) | Zero-setup transcript scanning | Data pipeline |
| [CU-0005](CU-0005-settings-window/CU-0005-settings-window.md) | Settings window & configurable scan locations | Settings & UX |
| [CU-0013](CU-0013-local-feature-instrumentation/CU-0013-local-feature-instrumentation.md) | Local feature-usage instrumentation | Data pipeline |

## 💡 Proposals

| ID | Item | Topic |
|---|---|---|
| [CU-0002](CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis.md) | Reimplement cost analysis natively in Swift (drop the python3 dependency) | Cost & budget |
| [CU-0006](CU-0006-session-block-tracking/CU-0006-session-block-tracking.md) | 5-hour session-block tracking with burn rate and limit forecast | Usage & quota |
| [CU-0007](CU-0007-server-quota-readout/CU-0007-server-quota-readout.md) | Opt-in server-truth quota readout | Usage & quota |
| [CU-0008](CU-0008-project-cost-breakdown/CU-0008-project-cost-breakdown.md) | Per-project cost & activity breakdown | Cost & budget |
| [CU-0009](CU-0009-multi-provider-usage/CU-0009-multi-provider-usage.md) | Multi-provider usage comparison (Codex / Gemini CLI) | Providers |
| [CU-0010](CU-0010-plan-and-unit-cost/CU-0010-plan-and-unit-cost.md) | Plan info & per-token unit-cost readout | Cost & budget |
| [CU-0011](CU-0011-today-usage/CU-0011-today-usage.md) | "Today" usage view | Settings & UX |
| [CU-0012](CU-0012-unused-skills-audit/CU-0012-unused-skills-audit.md) | Unused-skills audit over user-designated repo roots | Skills & tools |
| [CU-0014](CU-0014-self-experiments/CU-0014-self-experiments.md) | Time-sliced self-experiments on low-use features | Insights & experiments |
| [CU-0015](CU-0015-roadmap-gardener/CU-0015-roadmap-gardener.md) | Roadmap gardener: scheduled, evidence-driven proposal authoring | Workflow & automation |

## 🚧 In progress

_None yet._

## ❄️ Deferred

_None yet._

## Unsorted ideas

Rough thoughts not yet shaped into an item. Promote to a numbered item once the scope is clear.

- Edit-metrics (added / deleted lines) visualization — the data is already decoded.
- Signed / notarized release build automation (see [`release.sh`](../release.sh)).
</content>
