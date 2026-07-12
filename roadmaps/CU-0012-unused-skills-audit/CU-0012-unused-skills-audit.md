**English** · [日本語](CU-0012-unused-skills-audit-ja.md)

# CU-0012 — Unused-skills audit over user-designated repo roots

<!-- CU-METADATA -->
| Field | Value |
|---|---|
| Proposal | [CU-0012](CU-0012-unused-skills-audit.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Proposal** |
| Topic | Skills & tools |
<!-- /CU-METADATA -->

## Introduction

Find the skills you have but never use. The user designates one or more directories where
their git repositories live (e.g. `~/ghq/github.com/akidon0000`, `~/dev`); the app discovers
skill definitions in those repos, cross-references them against actual skill invocations in
the transcripts, and lists each skill with its last-used date — surfacing the ones that are
never invoked.

## Motivation

Skill inventories grow write-only: skills get authored, projects move on, and nobody knows
which of the dozens of definitions still earn their keep. The app already decodes skill
invocations from transcripts (the Skills tab) — but usage alone can't show what is *absent*.
Joining "skills that exist on disk" with "skills that appear in transcripts" turns the
inventory into an audit: delete candidates, stale directories, dead weight. No competitor
touches transcript-content analysis at all, so this deepens the app's main differentiation
axis.

## Detailed design

- **Designated roots (explicit, multi-select).** A Settings list where the user adds one or
  more directories via `NSOpenPanel` (security-scoped bookmarks, consistent with CU-0005's
  scan locations). Nothing is scanned that the user did not designate.
- **Bounded discovery — the root level and exactly one level below it.** For each designated
  root `R`, the scan looks only at `R` itself and its immediate children `R/<repo>` — no
  recursive descent. In each of those places it checks only known agent-config directories:
  - `.claude/skills/<name>/SKILL.md` (Claude Code skills)
  - `.claude/commands/*.md` (slash commands)
  - `.cursor/rules/` (Cursor rules), and similarly shallow, well-known locations for other
    editors' agent configs (extensible list)
  Nothing else in the repos is read or indexed. This keeps the scan fast, predictable, and
  privacy-conservative: the app never crawls source trees.
- **Usage join**: skill/command invocations already decoded from transcripts are matched by
  skill name (plus project path where available). Global skills (`~/.claude/skills/`) are
  included in the inventory by default, as today.
- **UI**: an "Audit" view in the Skills tab — table of skill, defining repo, last used,
  invocation count (30d / all), with an "unused" filter and sort. Unused = zero invocations
  in the scanned transcript history, clearly labeled with the history's actual time span
  (transcripts are pruned, so "unused in the last N days we can see").
- **Refresh**: rescan on demand and on the app's normal refresh cadence; results cached.

## Alternatives considered

**Recursive scan of designated roots.** Rejected per the requirement — repo collections can
be huge (node_modules, build trees); depth-limited known-directory probing is O(repos), not
O(files), and never surprises the user about what was read.

**Auto-detecting repo roots (ghq root, `~/src`, etc.).** Rejected for v1 — explicit
designation keeps consent unambiguous; a "suggest ghq root" convenience button can come later.

**Claiming a skill is globally unused.** Rejected wording — transcripts don't cover other
machines or pruned history; the UI always states the observed window.

## Progress

- [ ] TBD — Settings roots list, bounded discovery, usage join, Audit UI.

## References

- `Tokfuel/Sources/TranscriptScanner.swift` — skill-invocation decoding to join against.
- `Tokfuel/Sources/SettingsView.swift`, `AppSettings.swift` — scan-locations pattern (CU-0005) to extend.
- [CU-0005](../CU-0005-settings-window/CU-0005-settings-window.md) — security-scoped scan locations this builds on.
