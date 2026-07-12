**English** · [日本語](CU-0004-zero-setup-transcript-scanning-ja.md)

# CU-0004 — Zero-setup transcript scanning

<!-- CU-METADATA -->
| Field | Value |
|---|---|
| Proposal | [CU-0004](CU-0004-zero-setup-transcript-scanning.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Implemented** |
| Topic | Data pipeline |
| Implementing PR | — (landed locally) |
| Origin | back-fill (shipped before the roadmap existed) |
<!-- /CU-METADATA -->

## Introduction

Replace the hook-generated `~/.claude/usage/` JSON files with a native scanner that reads Claude
Code's own transcripts under `~/.claude/projects/` directly, so the app works the moment it is
installed — no hooks, no configuration.

## Motivation

The original data source was a set of per-repo JSON files that a user-authored Claude Code hook
had to produce. Anyone installing the app without that exact hook saw an empty popover. The
transcripts Claude Code always writes already contain everything the app needs (tool_use blocks,
prompts, timestamps, cwd), so reading them directly removes the entire setup burden — this is the
app's "install and it just works" foundation.

## Detailed design

`TranscriptScanner` walks `<claude-dir>/projects/**/*.jsonl` and aggregates per (project, day):

- **Line pre-filter.** Only lines containing `"tool_use"` (or a user prompt marker without
  `tool_result`) are JSON-decoded, so a multi-hundred-MB tree parses in ~1.5 s cold.
- **Counted signals.** `Skill` calls (by `input.skill`, plugin-prefix normalized), `mcp__*` tools,
  `Agent`/`Task` sub-agents (by `subagent_type`), and human prompts (non-sidechain user lines).
- **Project identity** from the record's `cwd` (`org/repo` for ghq-style paths), falling back to
  the transcript directory name.
- **Incremental cache.** Per-file summaries keyed by (path, mtime, size) persist in
  `~/Library/Application Support/Tokfuel/transcript-cache.json`; unchanged files are
  never re-read, and entries for deleted files are dropped.
- Output is the existing `RepoUsage` shape, so the aggregation and UI layers were unchanged.

## Alternatives considered

**Keep the hook-based `~/.claude/usage/` source.** Rejected — it makes every user author a hook
first, which contradicts an app whose value is glanceability.

**Parse every line as JSON.** Rejected — an order of magnitude slower on a 273 MB tree for no
additional signal; the marker pre-filter reads the same records.

## Progress

- [x] `TranscriptScanner` (marker pre-filter, per-day aggregation, project identity).
- [x] Incremental per-file cache with invalidation.
- [x] `~/.claude/usage/` loader removed; scan root configurable (see [CU-0005](../CU-0005-settings-window/CU-0005-settings-window.md)).

## References

- `Tokfuel/Sources/TranscriptScanner.swift`
- `Tokfuel/Sources/UsageStore.swift` (`reload`, aggregation)
- [CU-0003](../CU-0003-retok-cost-tab/CU-0003-retok-cost-tab.md) — retok reads the same transcripts for cost.
</content>
