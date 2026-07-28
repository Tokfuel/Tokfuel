**English** · [日本語](TF-0004-cursor-usage-ja.md)

# TF-0004 — Collect Cursor usage data

<!-- TF-METADATA -->
| Field | Value |
|---|---|
| Proposal | [TF-0004](TF-0004-cursor-usage.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Proposal** |
| Topic | Providers |
| Origin | Internal tester feedback (2026-07): "collect Cursor usage data too" |
<!-- /TF-METADATA -->

## Introduction

Show Cursor's AI usage (and cost, if derivable) alongside Claude Code, so people who split
their work across both tools see one combined number.

## Motivation

Several testers use Cursor as their primary editor and Claude Code for agent work. Tokfuel
currently answers "what did Claude Code cost" — for those users, that is only half the bill.

## Detailed design

**TBD — needs an investigation spike first.** Open questions, in order:

1. **What does Cursor persist locally?** Candidate sources: `~/Library/Application
   Support/Cursor/` (SQLite `state.vscdb`, logs). Determine whether request counts /
   model names / token usage are recoverable from disk.
2. **If local data is insufficient**, is there an authenticated usage API
   (as Cursor's dashboard uses)? That would be an opt-in network feature, mirroring how the
   removed server-quota feature was structured (token only, vendor only).
3. **Presentation.** A per-provider section in the popover; the hero stays the combined
   (or Claude-only) figure — decide once the data shape is known.

Ground rule: reading local files is always acceptable; any network fetch must be a separate
opt-in toggle and carry no usage data outbound.

## Alternatives considered

- **Do nothing** — Tokfuel stays Claude-only and single-purpose; still the fallback if
  Cursor persists nothing useful locally.

## Progress

- [ ] Spike: inventory what Cursor stores under Application Support (blocker for the rest)
- [ ] Decide local-only vs opt-in API
- [ ] Reader + popover section
- [ ] Include in budgets? (decide after the spike)

## References

- Feedback thread (internal, 2026-07-28)
