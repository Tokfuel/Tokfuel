---
name: roadmap-filter
description: >-
  List Tokfuel roadmap (TF) items filtered by their Status, so a session can survey
  everything that is a Proposal (or In progress / Implemented / Deferred) without reading the whole
  roadmaps/README.md. Use when you need an overview of the roadmap in one status — "what proposals
  are open?", "which items are implemented?", "list the deferred ones" — or to find the file path of
  items in a status before opening them. Read-only: it surveys the roadmap, never authors, implements,
  or edits any item.
---

# Roadmap status filter

Survey the roadmap by `Status`. This skill is **read-only and Claude-facing**: it lists the items in
one status so you can pick which to open in full.

## What it does

Each TF item's status lives in its own metadata block (`| Status | … |` in the English file,
`| 状態 | … |` in the Japanese). Rather than reading the whole index, grep the items directly.

```bash
# STATUS is one of: Proposal | In progress | Implemented | Deferred
STATUS="Proposal"
grep -rl "^| Status | \*\*${STATUS}\*\* |" roadmaps/*/TF-*.md 2>/dev/null | sort
```

For each hit, the path is the item's English `.md`; read it (swap `.md` → `-ja.md` for the Japanese
mirror). To also show the title, read the first `# TF-NNNN — …` line of each match:

```bash
for f in $(grep -rl "^| Status | \*\*${STATUS}\*\* |" roadmaps/*/TF-*.md); do
  printf '%s\t%s\n' "$(grep -m1 '^# TF-' "$f")" "$f"
done | sort
```

Valid statuses: `Proposal` (open, not started) / `In progress` (being built) / `Implemented`
(shipped) / `Deferred` (deliberately parked). An unknown status just returns no rows — the
authoritative buckets are the tables in [`roadmaps/README.md`](../../../roadmaps/README.md).

## How to use it

1. Run the grep for the status you care about.
2. Read the matched item(s) to find the one relevant to the task.
3. `Read` the path to get the full proposal text; that is exactly what to open next.

Keep the survey narrow: pull only the status you need, then open only the items that matter.
</content>
