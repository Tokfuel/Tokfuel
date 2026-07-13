**English** · [日本語](CU-0009-multi-provider-usage-ja.md)

# CU-0009 — Multi-provider usage comparison (Codex / Gemini CLI)

<!-- CU-METADATA -->
| Field | Value |
|---|---|
| Proposal | [CU-0009](CU-0009-multi-provider-usage.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Implemented** |
| Topic | Providers |
| Origin | [steipete/CodexBar](https://github.com/steipete/CodexBar) |
| Implementing PR | — (landed locally) |
<!-- /CU-METADATA -->

## Introduction

Read the local session logs of other AI coding CLIs — OpenAI Codex CLI (`~/.codex/`) and
Gemini CLI (`~/.gemini/`) to start — and show their usage next to Claude Code's, so a user
who works across assistants can compare tokens, estimated cost, and activity in one popover.

## Motivation

CodexBar (~18k stars) proved the demand: developers now run several coding agents and want one
menu-bar gauge, not one app per vendor. But CodexBar is deliberately broad and shallow — 58
provider meters, with Claude Code read by driving the CLI through a PTY and parsing `/usage`
output, which is fragile and requires the CLI to be installed. Tokfuel's position is the
inverse: deepest-in-class for Claude Code (transcript-content analytics), with *comparison*
meters for the neighbors a Claude-centric developer actually also uses. Codex CLI and Gemini
CLI both write local session logs in JSONL-like formats, so this fits the ground rules: local
file reads only, zero setup, no network.

## Detailed design

- **Provider abstraction**: a `UsageProvider` protocol (id, display name, log locations,
  scan → per-day tokens/cost/sessions) with the existing Claude pipeline as the first
  implementation. Providers whose log directory is absent simply don't appear.
- **Codex CLI reader**: parse `~/.codex/sessions/` (JSONL rollout files) for timestamps,
  models, and token usage events.
- **Gemini CLI reader**: parse `~/.gemini/tmp/<hash>/` session logs / telemetry files.
- **Cost estimation**: static pricing tables per provider model (same mechanism as
  [CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis.md)'s
  native pricing; ship as a bundled, updatable JSON).
- **UI**: a "Providers" comparison section — one row per detected provider with today/7d/30d
  tokens and est. cost, share-of-total bar, and last-activity time. Claude remains the default
  detail experience; other providers are summary-level in v1.
- **Settings**: per-provider toggle and extra scan paths, mirroring CU-0005.
- **Scope guard**: no OAuth, no cookies, no PTY driving, no server queries for other vendors —
  if a provider has no local logs, it is out of scope (that is CodexBar's game, not ours).

## Alternatives considered

**Match CodexBar's 50+ providers.** Rejected — breadth means auth flows, cookie reads, and
scrapers that violate local-only/zero-setup and are unmaintainable for a small app. Two or
three well-read local-log providers cover the actual overlap for Claude-first users.

**PTY-driving each CLI's usage command (CodexBar's Claude approach).** Rejected — fragile
against CLI output changes and requires the CLI binary; log files are the stable contract.

## Progress

- [x] Codex reader (`CodexUsageReader`): daily sessions + input/output tokens from
  `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` (last `total_token_usage` line per session,
  which is cumulative; `info: null` trailers ignored). Unit tests with real-shape fixtures
  (`tests/CodexUsageReaderTests.swift`) + verified against 40 real local sessions.
- [x] "Providers" section on the Tools tab (appears only when Codex logs exist): sessions as
  the cross-provider unit with a share bar, per-provider detail (Claude prompts / Codex
  tokens), last activity; respects the CU-0011 period filter.
- [x] **Gemini reader dropped, with evidence**: local Gemini CLI chat logs
  (`~/.gemini/tmp/*/chats/session-*.json`) carry no token-usage fields at all, so there is
  nothing to aggregate; revisit if Gemini CLI starts writing usage telemetry locally.
- [ ] Deferred to follow-ups: per-provider settings/extra scan paths (CU-0005 pattern),
  est. cost for Codex (needs the shared pricing JSON from CU-0002 — no guessed prices),
  a full `UsageProvider` protocol (premature with a single extra provider).

## References

- [steipete/CodexBar](https://github.com/steipete/CodexBar) — origin and prior art (breadth-first design).
- `Tokfuel/Sources/TranscriptScanner.swift`, `UsageStore.swift` — the Claude pipeline to generalize.
- [CU-0002](../CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis.md) — native pricing tables this reuses.
- [CU-0010](../CU-0010-plan-and-unit-cost/CU-0010-plan-and-unit-cost.md) — plan & unit-cost readout that complements the comparison.
