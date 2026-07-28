---
name: propose-and-build
description: >-
  Author a Tokfuel roadmap (TF) proposal and its implementation in one pass, for a
  small, well-scoped feature the author is confident in. Use when the user wants to "propose and
  build at once", "write the TF and the code together", instead of the serial ideation → implement-tf
  path. Composes the ideation skill (author the TF files) and the implement-tf skill (ship the code),
  landing both in a single branch/PR. Falls back to the serial path when the design is genuinely
  uncertain. Scope spans authoring and product code.
---

# propose-and-build

Author a roadmap (TF) item **and** its implementation in one pass, landing both in a single branch.
You are the author *and* the implementer; `swift build` plus the built-in review skills are the
check, never an LLM verdict. This composes the other two skills rather than restating them:

- [`ideation`](../ideation/SKILL.md) — authors a proposal, stops at the roadmap files.
- [`implement-tf`](../implement-tf/SKILL.md) — ships an already-numbered item from its ID.
- **`propose-and-build`** (this skill) — does both, for a small item settled enough to build now.

Because IDs in this repo are allocated **by hand** (no CI allocation), there is no placeholder /
two-PR-stack dance: you pick the real `TF-NNNN` up front and the proposal and code ride together.

## When to use it (and when not to)

Use it only for a **small, well-scoped item whose design you don't expect to change materially**:
a self-contained UI addition, a new setting, a contained analysis tweak. Fall back to the serial
[`ideation`](../ideation/SKILL.md) → [`implement-tf`](../implement-tf/SKILL.md) path when the design
is uncertain or wide-reaching — the point of the split is to let the proposal settle in review
before code is written. If in doubt, prefer the serial path.

## Project ground rules

The same five that bind the composed skills: local-only; zero setup stays zero; retok is vendored
unmodified; python3 is optional (graceful degrade); Swift 6 / SwiftUI / macOS 14+ with `swift build`
green. Re-read them in [`implement-tf`](../implement-tf/SKILL.md) before touching code.

## Workflow

1. **Branch** off the latest origin: `git fetch origin && git switch -c claude/cu-<slug> origin/main`.

2. **Author the proposal** exactly as [`ideation`](../ideation/SKILL.md) prescribes, with one
   change: allocate the **real** next ID now (`ls -d roadmaps/TF-*/ | sort | tail -1`, + 1) instead
   of a placeholder. Create `roadmaps/TF-NNNN-<slug>/` with both language files at `Status: Proposal`,
   and add the Proposals-table row in both READMEs.

3. **Implement** against that proposal as the spec, running [`implement-tf`](../implement-tf/SKILL.md)
   steps 2–6 (ground yourself, plan and confirm, implement with tests, review with `simplify` /
   `code-review` / `verify`).

4. **Flip to Implemented in the same change** (`implement-tf` step 7): set `Status: Implemented` and
   tick `Progress` in both language files, and move the row from the Proposals table to the
   Implemented table in both READMEs.

5. **Verify** (`implement-tf` step 8): `swift build` and `swift build -c release` green; `bash scripts/build.sh`
   + `verify` when the change is runtime-visible.

6. **PR only when asked** — one PR carries both the proposal and the implementation. Title:
   `[TF-NNNN] feat(<scope>): …`.

## References

- [`ideation`](../ideation/SKILL.md) — Phase 1 (authoring), composed here.
- [`implement-tf`](../implement-tf/SKILL.md) — Phases 2–5 (shipping), composed here.
- [`roadmaps/README.md`](../../../roadmaps/README.md) — the index and per-item format.
</content>
