**English** · [日本語](CU-0008-project-cost-breakdown-ja.md)

# CU-0008 — Per-project cost & activity breakdown

<!-- CU-METADATA -->
| Field | Value |
|---|---|
| Proposal | [CU-0008](CU-0008-project-cost-breakdown.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Proposal** |
| Topic | Cost & budget |
<!-- /CU-METADATA -->

## Introduction

Break usage down by project: a ranked list of projects with cost, tokens, session count, and
Skill/MCP activity per project, with a time-range filter. Answers "where is my money and quota
actually going?"

## Motivation

ccusage and CCSeva both offer per-project cost, and it is one of their most-cited features —
it turns a total into something actionable (archive that experiment repo, tune that noisy MCP
server). Our transcript layout under `~/.claude/projects/<encoded-path>/` already keys every
entry by project, so the dimension is free. Uniquely, we can join it with the Skill/MCP/agent
activity we already decode — a per-project view of *which tools burn the budget* is something
no competitor offers, and it deepens the app's main differentiation axis (transcript-content
analytics, not just token counting).

## Detailed design

- **Aggregation**: extend the scan pipeline (`TranscriptScanner` / `UsageStore`) to keep the
  project key per entry and aggregate cost/tokens/sessions/tool-calls per project. Decode the
  directory name back to a readable path; let the user assign a display alias.
- **UI**: a "Projects" tab (or section) in `PopoverView`: ranked bars by cost with share-of-total,
  expandable rows showing model mix and top Skills/MCP servers for that project.
- **Time range**: today / 7d / 30d / all — shared with (or mirroring) the Tools-tab filter idea
  already in Unsorted ideas.
- **Cost source**: retok's per-entry pricing when python3 is present; token counts alone
  (clearly labeled) when it is not, honoring the graceful-degradation rule. Native pricing
  arrives with [CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis.md).

## Alternatives considered

**Per-project budgets/alerts.** Deferred as follow-up — ship the breakdown first; alerts can
reuse the CU-0001 machinery per project later if wanted.

**A full dashboard window with charts.** Rejected for now — the menu-bar popover is the product;
a ranked list with expandable detail fits it. A dedicated window can be a later item if the
popover gets cramped.

## Progress

- [ ] TBD — per-project aggregation, Projects UI, time-range filter, alias mapping.

## References

- `ClaudeUsageMenubar/Sources/TranscriptScanner.swift`, `UsageStore.swift` — aggregation site.
- [ccusage](https://github.com/ryoppippi/ccusage) (`--breakdown`, per-project reports), [CCSeva](https://github.com/Iamshankhadeep/ccseva) — prior art.
- [CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis.md) — native pricing that removes the python3 caveat.
