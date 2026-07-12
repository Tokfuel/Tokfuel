**English** · [日本語](CU-0010-plan-and-unit-cost-ja.md)

# CU-0010 — Plan info & per-token unit-cost readout

<!-- CU-METADATA -->
| Field | Value |
|---|---|
| Proposal | [CU-0010](CU-0010-plan-and-unit-cost.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Proposal** |
| Topic | Cost & budget |
| Origin | [steipete/CodexBar](https://github.com/steipete/CodexBar) |
<!-- /CU-METADATA -->

## Introduction

Show *which plan you are on* and *what your tokens actually cost*: the detected Claude
plan (Pro / Max 5x / Max 20x / API), a per-model unit-price table (input / output / cache
read / cache write per Mtok), and derived efficiency stats — effective $/Mtok after cache
savings, cache hit rate, and API-equivalent value of a subscription ("this month's usage
would have been $X on the API").

## Motivation

Cost totals answer "how much", but not "am I on the right plan" or "is caching saving me
anything". CodexBar surfaces plan and billing-cycle info per provider and users cite it as a
key feature; Claude Code Usage Monitor's P90 plan auto-detection exists precisely because
people don't know what their plan implies. For subscription users, the single most
persuasive number a usage app can show is the API-equivalent dollar value — it justifies (or
questions) the subscription every month. All inputs are already local: transcripts carry
per-entry model and cache token counts, and pricing is a static table.

## Detailed design

- **Plan detection**: read locally available config/credential metadata (e.g.
  `~/.claude/.claude.json`, OAuth scope hints) to label the plan; fall back to "unknown —
  set manually" in Settings. When [CU-0007](../CU-0007-server-quota-readout/CU-0007-server-quota-readout.md)
  is enabled, use its server response as the authoritative source.
- **Unit-price table**: per-model $/Mtok for input / output / cache-read / cache-write from
  the bundled pricing JSON (shared with [CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis.md)
  / [CU-0009](../CU-0009-multi-provider-usage/CU-0009-multi-provider-usage.md)), shown in a
  compact reference view in the Cost tab.
- **Efficiency stats** (per period, computed from transcripts):
  - *Effective $/Mtok*: est. cost ÷ total tokens, per model and overall.
  - *Cache hit rate*: cache-read tokens ÷ (input + cache-read), and the dollars saved vs.
    uncached input pricing.
  - *API-equivalent value*: what the period's usage would cost at API list prices — headline
    stat for subscription users, with the plan's monthly fee alongside when known.
- **UI**: a "Plan" header line (plan badge + API-equivalent value) atop the Cost tab, an
  expandable unit-price table, and stat tiles for cache savings.

## Alternatives considered

**Only show raw totals (status quo).** Rejected by this proposal's premise — unit economics
is what makes the totals interpretable and is cheap to derive from data already decoded.

**P90-style plan inference from usage patterns.** Deferred — heuristic and confusing when
wrong. Local metadata + manual override covers v1; CU-0007 provides truth when opted in.

## Progress

- [ ] TBD — plan detection + manual override, pricing table view, efficiency stats, Cost-tab UI.

## References

- [steipete/CodexBar](https://github.com/steipete/CodexBar) — plan/billing readout prior art.
- [Anthropic pricing](https://www.anthropic.com/pricing) — the unit-price source of truth.
- `Tokfuel/Sources/UsageStore.swift`, `TranscriptScanner.swift` — token/cache counts already decoded.
- [CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis.md), [CU-0007](../CU-0007-server-quota-readout/CU-0007-server-quota-readout.md), [CU-0009](../CU-0009-multi-provider-usage/CU-0009-multi-provider-usage.md) — shared pricing table and plan truth.
