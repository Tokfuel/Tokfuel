**English** · [日本語](CU-0005-settings-window-ja.md)

# CU-0005 — Settings window & configurable scan locations

<!-- CU-METADATA -->
| Field | Value |
|---|---|
| Proposal | [CU-0005](CU-0005-settings-window.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Implemented** |
| Topic | Settings & UX |
| Implementing PR | — (landed locally) |
| Origin | back-fill (shipped before the roadmap existed) |
<!-- /CU-METADATA -->

## Introduction

Add a settings window (gear button in the popover header) covering launch-at-login, what the menu
bar shows, the default report period and language, budget settings, and — so the app works on any
machine layout — the scan locations (Claude directory and repository root).

## Motivation

Everything was hardcoded to the author's machine: `~/.claude` for transcripts and skills, `~/ghq`
for project skills, cost always in the menu bar, 30-day reports. Each of those is a preference,
and two of them (the paths) decide whether the app works at all for someone with a different
layout. A single settings surface, persisted in `UserDefaults`, makes the app usable beyond one
machine without touching code.

## Detailed design

`AppSettings` (an `ObservableObject` singleton over `UserDefaults`) holds:

- **Launch at login** — synced to `SMAppService.mainApp` (register/unregister); defaults to on at
  first launch so "install = resident" holds.
- **Menu-bar display** — today's cost / today's prompt count / icon only.
- **Report defaults** — period (7/30 days) and retok language (auto / en / ja).
- **Scan locations** — the Claude directory (default `~/.claude`; transcripts, global skills,
  plugin skills derive from it) and the repository root (default `~/ghq`; searched up to 3 levels
  for `.claude/skills`, so both `~/ghq/host/org/repo` and `~/src/repo` layouts work). Each row has
  a Finder folder picker and a reset-to-default button.
- Budget settings ride the same object ([CU-0001](../CU-0001-budget-alerts/CU-0001-budget-alerts.md)).

`AppDelegate` observes the published settings: path changes trigger a rescan, language/period
changes re-run retok, display changes redraw the status item. `SettingsView` is a grouped `Form`
in its own `NSWindow` (the app is an accessory, so the window is explicitly activated).

## Alternatives considered

**A preferences file the user edits by hand.** Rejected — this app's audience glances at a menu
bar; a GUI with pickers is the matching interaction, and `UserDefaults` is the platform norm.

**Auto-detecting repository roots** (scan the whole home directory). Rejected — unbounded I/O for
a value the user knows; a configurable root with a sensible default is cheaper and predictable.

## Progress

- [x] `AppSettings` (UserDefaults persistence) + `SettingsView` (grouped form, path pickers).
- [x] Launch-at-login via `SMAppService`, on by default at first launch.
- [x] Scan-location plumbing through `TranscriptScanner` / `UsageStore` / `RetokService` (`--dirs`).
- [x] Settings-change observers driving rescan / re-report / status redraw.

## References

- `ClaudeUsageMenubar/Sources/AppSettings.swift` · `SettingsView.swift` · `App.swift` (observers)
- [CU-0004](../CU-0004-zero-setup-transcript-scanning/CU-0004-zero-setup-transcript-scanning.md) — the scanner these paths feed.
</content>
