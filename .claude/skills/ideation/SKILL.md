---
name: ideation
description: >-
  Sounding board for Tokfuel feature ideation. Use when the user wants to brainstorm
  potential features, explore what the app could do next, or turn a rough idea into a roadmap (TF)
  item. Grounds the conversation in the existing roadmap, proposes new items or seeds, folds
  overlapping ideas into existing items, and — when the user is happy — drafts the TF files (EN + JA)
  under roadmaps/ with the next sequential ID. Scope is roadmap authoring only — it never implements
  the feature (that is the implement-tf skill).
---

# Ideation

A sounding board for shaping Tokfuel features into roadmap (TF) items. You are the
author and thinking partner, not the judge. Converse in the user's language; the roadmap is
bilingual, so write both files as required below.

## Scope: roadmap authoring only — never implement

This skill **only** authors and shapes roadmap (TF) items. It stops at the roadmap files under
`roadmaps/`. **Do not write, modify, or refactor any product code** (`Tokfuel/Sources/`,
tests, build scripts) even if the implementation seems obvious. The deliverable is always the TF
proposal, never a working feature.

If the user asks you to build an idea, don't switch hats mid-session: point them to
[`implement-tf`](../implement-tf/SKILL.md), or — when the item is small and its design is settled —
[`propose-and-build`](../propose-and-build/SKILL.md), which authors and implements in one pass.

## Project ground rules (these bound every idea)

Any idea must respect these; say so when an idea brushes a boundary and reshape it rather than
silently dropping it.

1. **Local-only.** Collected data never leaves the Mac. Don't propose telemetry or any network send.
2. **Zero setup stays zero.** Don't assume hooks or extra installs; the app reads Claude Code
   transcripts directly. A feature that requires the user to configure Claude Code first fights this.
3. **retok is vendored unmodified.** Don't propose editing the bundled retok in place (upstream PR
   instead); keep its MIT license and attribution intact. See [TF-0001](../../../roadmaps/TF-0001-native-swift-cost-analysis/TF-0001-native-swift-cost-analysis.md)
   for the native-port path.
4. **python3 is an optional dependency.** The app must keep degrading gracefully without it
   (Cost tab shows an error; other tabs work).
5. **Swift 6 / SwiftUI / macOS 14+.** `swift build` must stay green.

## Workflow

### 1. Ground yourself in the existing roadmap

Read [`roadmaps/README.md`](../../../roadmaps/README.md) (and `README-ja.md`) — the index of every
TF item, its topic and status — and the specific `TF-NNNN-*/` files relevant to the topic. Use
[`roadmap-filter`](../roadmap-filter/SKILL.md) to survey one status quickly. Every suggestion is
anchored to what is already planned, shipped, or deliberately parked — that is what makes it a
sounding board and not a blank page.

### 2. Ideate with the user

Go back and forth. Offer concrete, bounded ideas; ask the questions that sharpen scope (who is it
for, what is the observable outcome). Pull in adjacent items as reference points ("this is close to
TF-00xx — extend it, or is it distinct?").

### 3. Classify each surviving idea — tell the user which and why

- **Overlaps an existing TF item** → don't duplicate. Augment that item's files (both languages).
- **Novel and scoped enough** → draft a new TF item (step 4).
- **Still unformed** → add a bullet under **Unsorted ideas** in both READMEs; promote later.

### 4. Draft a new TF item

Allocate the next ID = highest existing `TF-NNNN` + 1:

```bash
ls -d roadmaps/TF-*/ | sort | tail -1
```

Create `roadmaps/TF-NNNN-<slug>/` with both `TF-NNNN-<slug>.md` and `TF-NNNN-<slug>-ja.md`.
Copy the shape from an existing item (e.g. [TF-0001](../../../roadmaps/TF-0001-budget-alerts/TF-0001-budget-alerts.md)):
the bilingual header link, the `<!-- TF-METADATA -->` block (`Proposal` / `Author` / `Status: Proposal`
/ `Topic`), and the sections `Introduction` / `Motivation` / `Detailed design` /
`Alternatives considered` / `Progress` / `References`. Fill unknowns with `TBD`.

Write the Japanese side under [`japanese-tech-writing`](../japanese-tech-writing/SKILL.md) — 敬体,
natural Japanese, not a literal rendering of the English. Then **add a row** to the Proposals table
in both README files by hand.

### 5. Verify and finish

Run `bash scripts/lint_roadmap.sh` — it checks the EN/JA pair, the metadata block, the bilingual
cross-links, and the index rows (CI runs the same script). Commit with a scoped message
(`docs(roadmap): add TF-NNNN <slug>`). Open a PR only if the user asks.

## References

- [`roadmaps/README.md`](../../../roadmaps/README.md) — the index and the per-item format.
- [`implement-tf`](../implement-tf/SKILL.md) — the counterpart that ships a numbered item.
- [`propose-and-build`](../propose-and-build/SKILL.md) — author + implement in one pass.
- [`japanese-tech-writing`](../japanese-tech-writing/SKILL.md) — the norm for the `-ja.md` side.
</content>
