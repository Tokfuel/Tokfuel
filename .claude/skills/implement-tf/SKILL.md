---
name: implement-tf
description: >-
  Implement a Tokfuel issue end to end, starting from its GitHub Issue number. Use when the
  user names an issue to build — "/implement-tf #5", "implement #5", "start on #5", or an issue
  title fragment — or otherwise asks to turn an existing proposal into shipped code. Treats the
  issue body as the spec, grounds the work in the project ground rules, plans and confirms before
  writing, implements with build/tests, reviews and refines the diff, closes the issue, and proves
  `swift build` is green. The counterpart to the ideation skill.
---

# Implement a GitHub Issue

Take one Tokfuel GitHub Issue from its proposal to shipped, green code. You are the implementer;
`swift build` (plus the built-in review skills) is the check — never an LLM verdict. The issue's
**Detailed design** section is your spec. Converse in the user's language; write code, commits, and
PR text per the conventions below.

## Project ground rules (these bound every line)

1. **Local-only** — never add telemetry or a network send.
2. **Zero setup stays zero** — don't require the user to configure Claude Code or install hooks.
3. **retok is vendored unmodified** — don't edit the bundled retok in place; keep its license/credit.
4. **python3 is optional** — keep the Cost tab degrading gracefully when it is absent.
5. **Swift 6 / SwiftUI / macOS 14+** — `swift build` must stay green.

## Workflow

### 1. Resolve the issue

Accept an issue number (`#5`, `5`) or a title fragment. Fetch the full issue body:

```bash
gh issue view <number> --repo Tokfuel/Tokfuel --json number,title,body,labels 2>/dev/null
```

**Before anything else, explain the issue to the user** — the number and title, a plain-language
summary of what it proposes and why, and its current state. Confirm: if it is already closed, stop
and ask what the user actually wants.

### 2. Ground yourself in the spec and the code

- Read the issue's **Detailed design** and any alternatives or constraints mentioned.
- Open every file the issue references and read the surrounding code, so the change matches
  what exists. For a large item, fan the reading out to the `Explore` agent and draft the strategy
  with the `Plan` agent.
- Check dependencies: if the design cross-references another open issue as a blocker, surface it
  and ask how to proceed.

### 3. Set up a focused branch

One topic per branch. If on `main`, branch off the latest origin:
`git fetch origin && git switch -c claude/<slug> origin/main`. Touch only the files this
issue needs; if the design forces a cross-cutting change, say so up front.

### 4. Plan, then confirm before writing code

Implementing a whole issue is large and hard to reverse, so get the user's go-ahead on a concrete
plan first (consider `EnterPlanMode`). The plan names: the files you'll add/change and the shape of
the change; the observable outcome that proves it works (a test, or a behavior to verify in the
running app); the tests you'll add; any docs that must move (both languages); and any tension with
the ground rules and how you reshaped the design to fit.

### 5. Implement

- **Match surrounding style.** Comments explain *why*, not what, at the surrounding density.
- **Honor the ground rules in the code** — local-only, graceful python3 absence, retok untouched.
- **Tests are the regression net.** Cover new logic where it is testable without the full app.
- **Docs are bilingual.** If you change documented behavior, update `README.md` **and**
  `README.ja.md`; write the Japanese under [`japanese-tech-writing`](../japanese-tech-writing/SKILL.md).

### 6. Review and refine the diff

`swift build` proves it compiles; it does not judge design or logic. Close that gap on the diff,
every time:

- Invoke the built-in **`simplify`** skill (reuse, dead code, over-abstraction) and apply its fixes.
- Invoke the built-in **`code-review`** skill for correctness bugs the build can't see.
- If the item's correctness depends on runtime behavior, drive the running app with the built-in
  **`verify`** skill — build and install via `bash scripts/build.sh`, exercise the behavior,
  and report what you saw — rather than claiming it works untested.

### 7. Verify

```bash
swift build                    # must be green
swift build -c release         # the release config scripts/build.sh uses
```

Never leave the build red. Then, when the change is runtime-visible, `bash scripts/build.sh` and
confirm the running app (via `verify`).

### 8. PR only when asked

Push to your branch. Don't open a PR unless the user asks. Title and commits are imperative and
scoped: `feat(<scope>): …` or `fix(<scope>): …`. Include `Closes #<number>` in the PR body to
auto-close the issue on merge.

## References

- [`ideation`](../ideation/SKILL.md) — authors the proposal this ships.
- The built-in **`simplify`** / **`code-review`** / **`verify`** skills — used in steps 6/7.
