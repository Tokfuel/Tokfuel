---
title: "Keep app-related trees under App/"
status: Accepted
proposed: 2026-08-08
accepted: 2026-08-08
supersedes:
issue: "#134"
---

# Keep app-related trees under App/

[日本語](./0001-app-tree.ja.md)

## Decision

> What was decided about the architecture or solution

### Decision

Fix the home for the app and verification artifacts as follows:

- `App/Tokfuel/` — app code (formerly `Tokfuel/Sources`). After the SPM layer split, the executable and libraries sit under `App/Tokfuel*`
- `App/Tests/` — parent for verification (formerly `Tokfuel/Tests`, plus TestDocs / E2E)
  - `UnitTests/` — unit tests (`swift test` target)
  - `IntegrationTests/` — integration tests (later)
  - `TestDocs/` — scenario design (not executed)
  - `E2E/` — end-to-end implementations (not under `swift test`)

Site is out of scope. Behavior does not change; only layout and path references change.

The directories are renamed, not only moved. Leaving names like `Sources` / `Tests` reads as “the whole repository’s sources,” which blurs scope. Prefer a product-shaped name (`App/Tokfuel`) and keep verification under `App/Tests/` so the product tree stays separate from Site / Docs / Scripts.

### Summary of alternatives

Keeping the old layout would scatter TestDocs / E2E later. Placing siblings at the repo root grows entry points and mixes them with Site and other ops trees. Gathering under `App/` gives one parent for app-related work, so option 3 is adopted.

## Context

> Background, problem, and goal for this decision

### Background

App code lived in `Tokfuel/Sources` and tests in `Tokfuel/Tests`, referenced from a single SPM target. We needed in-repo homes for scenario design (TestDocs) and end-to-end tests (E2E) (#134). Putting those at the root or in separate trees multiplies “where do I look?” for app work.

### Problems

1. **Scattered homes**
   - When app, UT/IT, design docs, and E2E sit in different hierarchies, contributors hunt for the right place and unrelated changes tend to land in one PR.
2. **No room to grow the next boxes**
   - Without a decided parent for TestDocs / E2E, ad-hoc conventions appear and clash with later module splits (#109).
3. **Names that do not show scope**
   - Root-level or `Tokfuel/Sources` reads as “all sources.” We want a parent that clearly means the product tree.

### Goals

- One discovery entry for app-related work: `App/`
- Room for TestDocs / E2E under the same tree
- Fix layout policy only; do not change runtime behavior

## Consideration

> Alternatives that were considered

### Options

| Option | Solution | Overview |
|--------|----------|----------|
| 1 | **Status quo** | Keep `Tokfuel/Sources` + `Tokfuel/Tests`; add TestDocs / E2E elsewhere later |
| 2 | **Top-level siblings** | Place `Tokfuel/` (or `Sources/`), `Tests/`, `TestDocs/`, and `E2E/` as siblings at the repo root |
| 3 | **Gather under `App/`** | `App/Tokfuel*` and `App/Tests/{UnitTests,IntegrationTests,TestDocs,E2E}` |

### Comparison

| Criterion | 1 Status quo | 2 Top-level siblings | 3 Under `App/` |
|-----------|--------------|----------------------|----------------|
| Discoverability | × More entry points as boxes grow | △ Siblings align, but sit next to Site / Docs | ◎ One parent for app-related work |
| Growing TestDocs / E2E | × Placement conventions come late | ○ Can sit side by side without a shared product parent | ◎ Can grow under the same `App/` |
| Migration cost | ◎ No change | ○ Path updates, shallow | ○ Path updates required; no behavior change |
| Fit with #109 | △ Weak “inside the app” boundary | △ Product and ops mixed at root | ○ Module work can stay scoped under `App/` |
| Impact on Site | ◎ Untouched | ◎ Untouched (but neighbors at root) | ◎ Stays outside, out of scope |

### Overall

| Option | Assessment | Verdict |
|--------|------------|---------|
| 1: Status quo | Scattering and follow-on boxes remain unsolved | **Rejected** |
| 2: Top-level siblings | More entry points; product boxes mix with ops at the same level | **Rejected** |
| 3: Under `App/` | One parent for app-related work; Site stays outside | **Accepted** |

## Consequences

> Expected effects on the system and project

### Expected benefits

1. One discovery entry under `App/`, with room for TestDocs / E2E in the same tree
2. A directory boundary between product code and ops trees (Site / Docs / Scripts)
3. Easier scoping for later module splits (#109) as work “inside the app”

### Risks and mitigations

| Risk | Detail | Mitigation |
|------|--------|------------|
| Missed path updates | `Package.swift`, CI, scripts, or docs still point at old paths | Update in the #134 implementation; verify with `swift test` / `swift build -c release` |
| Broken external links | Bookmarks or forks still cite old paths | Update README / AGENTS; no runtime impact because behavior is unchanged |
| Scope creep | Folding version-source or other top-level renames into this decision | This ADR covers **`App/` consolidation only**; other topics stay separate |

## References

> Related links

- Issue: [#134](https://github.com/Tokfuel/Tokfuel/issues/134)
- PR: [#135](https://github.com/Tokfuel/Tokfuel/pull/135)
- Related ADR: (none)
- Related issue: [#109](https://github.com/Tokfuel/Tokfuel/issues/109) (module split; out of scope here)
