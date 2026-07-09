---
name: task-select
description: >-
  Select the next task to work on from the Claude Usage Menubar roadmap (and, if present, open
  GitHub Issues / PRs). Use when the user says "次のタスクを検討して", "タスクを選定して", "次に
  進めるべきタスクを", or asks to pick the next item to implement. Reads roadmap status and any open
  issues, filters by criteria (e.g. Proposal status), and presents ranked candidates with rationale.
  Read-only — it never implements, creates branches, or opens PRs.
---

# Task selection

Survey the roadmap (and open issues, if the repo uses them) to recommend the next task. This is a
**read-only, advisory** skill — it never implements features or creates branches.

## Steps

1. **Gather context**
   - Survey open proposals with [`roadmap-filter`](../roadmap-filter/SKILL.md) (`Status: Proposal`),
     and glance at `In progress` to avoid stepping on active work.
   - If the repo tracks work in GitHub, also check open issues and PRs (skip silently if none):
     ```bash
     gh issue list --state open --limit 50 2>/dev/null
     gh pr list --state open --limit 30 2>/dev/null
     ```

2. **Filter** by the user's criteria if given (e.g. "proposals only", a specific topic).

3. **Rank candidates** considering:
   - Dependencies — items that unblock others rank higher (check each item's `References`).
   - Scope — prefer items completable in a single session.
   - Topic clustering — items in the same area share context.
   - Ground-rule fit — an item that fits the project's local-only / zero-setup / retok-untouched
     constraints cleanly is lower-risk than one that strains them.

4. **Present** a short ranked list (3–5 candidates), each with: the CU ID and title, a one-line
   rationale, and any blocker or dependency to be aware of.

5. **Wait for the user's choice.** When they pick one, recommend
   [`/implement-cu CU-NNNN`](../implement-cu/SKILL.md) to start (or
   [`/propose-and-build`](../propose-and-build/SKILL.md) for a small new idea not yet on the roadmap).

## What this skill does NOT do

- Implement features or write code.
- Create branches or PRs.
- Change roadmap status or metadata.
</content>
