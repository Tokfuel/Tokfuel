**English** · [日本語](CU-0007-server-quota-readout-ja.md)

# CU-0007 — Opt-in server-truth quota readout

<!-- CU-METADATA -->
| Field | Value |
|---|---|
| Proposal | [CU-0007](CU-0007-server-quota-readout.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Implemented** |
| Topic | Usage & quota |
| Implementing PR | — (landed locally) |
<!-- /CU-METADATA -->

## Introduction

An **opt-in** feature that reads the OAuth credentials Claude Code already stores locally and
queries Anthropic's usage endpoint to display the *server-truth* plan quota percentages (5-hour
window, weekly, per-model) — the same numbers the official `/usage` command shows — without any
manual token setup.

## Motivation

Local transcript aggregation (CU-0006) is an estimate; users of CCSeva, Usage4Claude, and the
Raycast ccusage extension consistently praise the server-side quota percentage, and "your number
disagrees with `/usage`" is the standard complaint against purely local tools. Usage4Claude makes
users paste a session key by hand; CCSeva reads OAuth but is Electron-based. We can have both
advantages: reuse the credentials Claude Code already maintains (zero setup preserved) inside a
native app. Combined with CU-0006 this gives estimate-when-offline, truth-when-enabled.

## Detailed design

- **Off by default.** The ground rule is *no network sends*; this feature makes a request to
  Anthropic's own API carrying only the user's existing OAuth token — no usage data, no
  third-party host. The Settings toggle states this explicitly, and everything else in the app
  keeps working with the toggle off.
- **Credential source**: Claude Code's stored OAuth credentials (Keychain item, or
  `~/.claude/.credentials.json` where applicable). Read-only; never write or refresh-race
  Claude Code's own token handling. If the token is expired/absent, show a gentle "open Claude
  Code to refresh" hint and fall back to the CU-0006 estimate.
- **Endpoint**: the usage/rate-limit endpoint the official client uses (as used by CCSeva and
  the Raycast extension). Poll on the app's existing refresh cadence, with backoff on errors.
- **UI**: in the Session view (CU-0006), show the server percentages as the primary figure with
  the local estimate as secondary; menu-bar readout and notifications switch to server values
  when available.
- **Privacy note** in README (both languages): what is sent (the token, to Anthropic only),
  what is never sent (transcripts, costs, anything else).

## Alternatives considered

**Manual session-key entry (Usage4Claude's approach).** Rejected — breaks zero setup and keys
expire, creating recurring friction.

**Stay purely local.** That is the default state of this feature; this item exists precisely
because the estimate/truth gap is the top user complaint against local-only tools. Opt-in keeps
the principle intact for users who never flip the switch.

**Official OTel telemetry.** Rejected — requires the user to configure Claude Code and an OTLP
backend; setup-heavy and aimed at teams.

## Progress

- [x] Spike (via CodexBar source study, MIT © Peter Steinberger): endpoint is
  `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer`,
  `anthropic-beta: oauth-2025-04-20`; response carries `five_hour` / `seven_day` /
  `seven_day_opus` `{utilization, resets_at}`. Credentials live in
  `~/.claude/.credentials.json` (`claudeAiOauth.accessToken`) or the Keychain item
  `"Claude Code-credentials"`; the token is never refreshed by us (rotation conflicts —
  CodexBar delegates to the CLI the same way).
- [x] `ClaudeQuotaService` (credential discovery file → Keychain, fetch, decode) + unit
  tests (`tests/ClaudeQuotaTests.swift`).
- [x] Settings toggle, off by default, with an explicit "what is sent" footer.
- [x] "Limits" section atop the Cost tab: 5h / 7d / 7d-Opus bars with reset countdowns.
- [x] Local plan badge from `~/.claude.json` `oauthAccount.userRateLimitTier` (no network;
  also a first slice of CU-0010's plan detection).
- [ ] Deferred: menu-bar/notification switch-over to server values (belongs to CU-0006's
  session view), poll backoff beyond the app's refresh cadence.

## References

- [CU-0006](../CU-0006-session-block-tracking/CU-0006-session-block-tracking.md) — the local estimate this augments.
- [CCSeva](https://github.com/Iamshankhadeep/ccseva), [Usage4Claude](https://github.com/f-is-h/Usage4Claude), [Raycast ccusage extension](https://www.raycast.com/nyatinte/ccusage) — prior art for server-truth quota display.
- `CLAUDE.md` ground rule 1 (local-only) — the boundary this item deliberately negotiates via opt-in.
