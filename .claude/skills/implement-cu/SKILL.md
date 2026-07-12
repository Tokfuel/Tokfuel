---
name: implement-cu
description: >-
  Implement a Tokfuel roadmap (CU) item end to end, starting from its ID. Use when the
  user names a roadmap item to build — "/implement-cu CU-0002", "implement CU-0002", "start on
  CU-0002", a bare number, or a slug — or otherwise asks to turn an existing CU proposal into shipped
  code. Treats the item's proposal as the spec, grounds the work in the project ground rules, plans
  and confirms before writing, implements with the build/tests, reviews and refines the diff, flips
  the item to Implemented, and proves `swift build` is green. The counterpart to the ideation skill.
---

# Implement a CU item

Take one roadmap (CU) item from its proposal to shipped, green code. You are the implementer;
`swift build` (plus the built-in review skills) is the check — never an LLM verdict. The proposal's
**Detailed design** is your spec. Converse in the user's language; write code, commits, and PR text
per the conventions below.

## Project ground rules (these bound every line)

1. **Local-only** — never add telemetry or a network send.
2. **Zero setup stays zero** — don't require the user to configure Claude Code or install hooks.
3. **retok is vendored unmodified** — don't edit the bundled retok in place; keep its license/credit.
4. **python3 is optional** — keep the Cost tab degrading gracefully when it is absent.
5. **Swift 6 / SwiftUI / macOS 14+** — `swift build` must stay green.

## Workflow

### 1. Resolve the item

Accept a full ID (`CU-0002`), a bare number (`2` / `0002`), or a slug fragment:

```bash
ls -d roadmaps/CU-*<id-or-slug>*/
```

Read **both** language files; the English `CU-NNNN-<slug>.md` is the authoritative spec.

**Before anything else, explain the item to the user** — the ID and title, its Status/Topic, a
plain-language summary of what it proposes and why, and its current state. Then note: if it is a
`Proposal`, implementing it *accepts* it (this change flips it to `Implemented`); if already
`Implemented`, stop and confirm what the user actually wants; if `Deferred`, confirm they want to
un-defer it.

### 2. Ground yourself in the spec and the code

- Read the proposal's **Detailed design** and **Alternatives considered** (the latter records
  rejected paths — don't re-propose them).
- Open every file the proposal references and read the surrounding code, so the change matches
  what exists. For a large item, fan the reading out to the `Explore` agent and draft the strategy
  with the `Plan` agent.
- Check dependencies: if the design leans on another CU item still in `Proposal`, surface it as a
  blocker and ask how to proceed.

### 3. Set up a focused branch

One topic per branch. If on `main`, branch off the latest origin:
`git fetch origin && git switch -c claude/cu-NNNN-<slug> origin/main`. Touch only the files this
item needs; if the design forces a cross-cutting change, say so up front.

### 4. Plan, then confirm before writing code

Implementing a whole item is large and hard to reverse, so get the user's go-ahead on a concrete
plan first (consider `EnterPlanMode`). The plan names: the files you'll add/change and the shape of
the change; the observable outcome that proves it works (a test, or a behavior to verify in the
running app); the tests you'll add; any docs that must move (and therefore need both languages);
and any tension with the ground rules and how you reshaped the design to fit.

### 5. Implement

- **Match surrounding style.** Comments explain *why*, not what, at the surrounding density.
- **Honor the ground rules in the code** — local-only, graceful python3 absence, retok untouched.
- **Tests are the regression net.** Cover new logic where it is testable without the full app
  (the pattern used for `BudgetMonitor` / `TranscriptScanner`: a small `swiftc` harness over the
  source files, run headless).
- **Docs are bilingual.** If you change documented behavior, update `README.md` **and**
  `README.ja.md`; write the Japanese under [`japanese-tech-writing`](../japanese-tech-writing/SKILL.md).

### 6. Review and refine the diff

`swift build` proves it compiles; it does not judge design or logic. Close that gap on the diff,
every time:

- Invoke the built-in **`simplify`** skill (reuse, dead code, over-abstraction) and apply its fixes.
- Invoke the built-in **`code-review`** skill for correctness bugs the build can't see.
- If the item's correctness depends on runtime behavior, drive the running app with the built-in
  **`verify`** skill — build and install via [`build.sh`](../../../build.sh), exercise the behavior,
  and report what you saw — rather than claiming it works untested.

### 7. Flip the item to Implemented

In **both** language files, set the metadata `Status` to **Implemented**, tick the `Progress`
boxes, and add an `Implementing PR` row once a PR number exists (or `— (landed locally)`). Then move
the item's row from the Proposals table to the Implemented table in **both** README files. Never
renumber the item — its ID is permanent.

### 8. Verify

```bash
swift build                    # must be green
swift build -c release         # the release config build.sh uses
bash scripts/lint_roadmap.sh   # the Status flip touched roadmaps/ — CI checks this too
```

Never leave the build red. Then, when the change is runtime-visible, `./build.sh` and confirm the
running app (via `verify`).

### 9. PR only when asked

Push to your branch. Don't open a PR unless the user asks. Title and commits are imperative and
scoped, prefixed with the ID: `[CU-NNNN] feat(<scope>): …`.

## References

- [`roadmaps/README.md`](../../../roadmaps/README.md) — the index and per-item format.
- [`ideation`](../ideation/SKILL.md) — authors the proposal this ships.
- [`propose-and-build`](../propose-and-build/SKILL.md) — author + implement in one pass for a small item.
- The built-in **`simplify`** / **`code-review`** / **`verify`** skills — the review aids steps 6/8 use.
</content>
