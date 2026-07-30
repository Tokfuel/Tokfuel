---
name: ideation
description: >-
  Sounding board for Tokfuel feature ideation. Use when the user wants to brainstorm
  potential features, explore what the app could do next, or turn a rough idea into a GitHub Issue.
  Grounds the conversation in open issues, proposes new items or seeds, folds overlapping ideas into
  existing issues, and — when the user is happy — opens a GitHub Issue with the proposal body.
  Scope is proposal authoring only — it never implements the feature (that is the implementation skill).
---

# Ideation

A sounding board for shaping Tokfuel features into GitHub Issues. You are the author and thinking
partner, not the judge. Converse in the user's language.

## Scope: proposal authoring only — never implement

This skill **only** authors and shapes proposals. The deliverable is always a GitHub Issue, never
working code. Do not write, modify, or refactor any product code (`Tokfuel/Sources/`, tests, build
scripts) even if the implementation seems obvious.

If the user asks you to build an idea, point them to [`implementation`](../implementation/SKILL.md).

## Project ground rules (these bound every idea)

Any idea must respect these; say so when an idea brushes a boundary and reshape it rather than
silently dropping it.

1. **Local-only.** Collected data never leaves the Mac. Don't propose telemetry or any network send.
2. **Zero setup stays zero.** Don't assume hooks or extra installs; the app reads Claude Code
   transcripts directly. A feature that requires the user to configure Claude Code first fights this.
3. **retok is vendored unmodified.** Don't propose editing the bundled retok in place (upstream PR
   instead); keep its MIT license and attribution intact. The shipped cost analyzer is the Swift
   port in `Sources/Retok/` (issue #5) — proposals touching cost logic must keep it in parity.
4. **Swift 6 / SwiftUI / macOS 14+.** `swift build` must stay green.

## Workflow

### 1. Ground yourself in existing issues

```bash
gh issue list --repo Tokfuel/Tokfuel --state open --limit 50 \
  --json number,title,labels,body 2>/dev/null
```

Every suggestion is anchored to what is already planned or deliberately parked — that is what makes
this a sounding board and not a blank page.

### 2. Ideate with the user

Go back and forth. Offer concrete, bounded ideas; ask the questions that sharpen scope (who is it
for, what is the observable outcome). Pull in adjacent issues as reference points ("this is close to
#5 — extend it, or is it distinct?").

### 3. Classify each surviving idea — tell the user which and why

- **Overlaps an existing issue** → don't duplicate. Suggest amending that issue's body.
- **Novel and scoped enough** → draft a new issue (step 4).
- **Still unformed** → note it in the conversation and come back later.

### 4. Draft and open a new issue

When the user is happy with the shape, open a GitHub Issue using the Proposal template format:
- **Title:** short imperative phrase, no issue number prefix.
- **Body (enhancement):** Introduction paragraph → `## Detailed design` → `## Progress` checklist.
- **Body (bug):** Description paragraph → Root cause → Fix → `**Relevant files:**` list → `## Progress` checklist.
- Reference relevant files/symbols inline. Cross-link blocking or related issues with `#N`.
- **Label:** `enhancement 🚀` for features, `bugs 🐞` for bugs.

```bash
gh issue create --repo Tokfuel/Tokfuel \
  --title "<title>" \
  --label "enhancement 🚀" \
  --body "<body>" 2>/dev/null
```

Then add it to the roadmap project:

```bash
gh project item-add 1 --owner Tokfuel \
  --url "https://github.com/Tokfuel/Tokfuel/issues/<number>" 2>/dev/null
```

## References

- [`implementation`](../implementation/SKILL.md) — the counterpart that ships an issue.
- [`japanese-tech-writing`](../japanese-tech-writing/SKILL.md) — for Japanese-language sessions.
