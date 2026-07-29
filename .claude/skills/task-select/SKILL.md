---
name: task-select
description: >-
  Select the next task to work on from GitHub Issues. Use when the user says
  "次のタスクを検討して", "タスクを選定して", "次に進めるべきタスクを", or asks to pick the next item
  to implement. Fetches open issues, filters by label/criteria, and presents ranked candidates
  with rationale. Read-only — it never implements, creates branches, or opens PRs.
---

# Task selection

Survey open GitHub Issues to recommend the next task. This is a **read-only, advisory** skill —
it never implements features or creates branches.

## Steps

1. **Fetch open issues**

   ```bash
   gh issue list --repo Tokfuel/Tokfuel --state open --limit 50 \
     --json number,title,labels,body 2>/dev/null
   ```

   Also check for in-progress work to avoid stepping on it:

   ```bash
   gh pr list --repo Tokfuel/Tokfuel --state open --limit 20 \
     --json number,title,headRefName 2>/dev/null
   ```

2. **Filter** by the user's criteria if given (e.g. "bugs only", a specific topic label,
   "enhancement only"). Labels in use: `bug`, `enhancement`.

3. **Rank candidates** considering:
   - Dependencies — issues that unblock others rank higher (check the issue body's
     cross-references such as "see #N").
   - Scope — prefer issues completable in a single session.
   - Topic clustering — issues in the same area share context.
   - Ground-rule fit — an issue that fits the project's local-only / zero-setup /
     retok-untouched constraints cleanly is lower-risk than one that strains them.

4. **Present** a short ranked list (3–5 candidates), each with: the issue number and title,
   a one-line rationale, and any blocker or dependency to be aware of.

5. **Wait for the user's choice.** When they pick one, recommend
   [`/implement-tf`](../implement-tf/SKILL.md) to start, passing the issue number
   (e.g. `/implement-tf #5`).

## What this skill does NOT do

- Implement features or write code.
- Create branches or PRs.
- Close or edit issues.
