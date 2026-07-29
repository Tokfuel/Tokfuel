**English** · [日本語](TF-0007-windows-linux-support-ja.md)

# TF-0007 — Windows / Linux support

<!-- TF-METADATA -->
| Field | Value |
|---|---|
| Proposal | [TF-0007](TF-0007-windows-linux-support.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Proposal** |
| Topic | Platforms |
| Origin | Internal feedback (2026-07): teammates on Windows / Linux want the same readout |
<!-- /TF-METADATA -->

## Introduction

Bring Tokfuel's cost readout to Windows and Linux, where Claude Code also runs and writes the
same `~/.claude/projects/` transcripts.

## Motivation

Claude Code is cross-platform; Tokfuel is not. Teammates on Windows (including WSL) and Linux
have the same transcripts on disk and the same "what did today cost?" question, but no way to
see it. Cost visibility per member matters more, not less, once a whole team adopts the tool.

## Detailed design

**TBD — the approach decision is the actual work.** The current app is SwiftUI +
NSStatusItem and does not port. Candidate paths:

1. **Separate lightweight tray app** (Rust `tray-icon` / Go `systray` / Tauri):
   reimplement only the essentials — read transcripts, run the bundled retok (or the
   TF-0001 native analyzer logic), show today's / monthly cost and budget colors in the
   system tray. macOS app stays as-is.
2. **CLI-first**: ship the analyzer as a small cross-platform CLI (`tokfuel report --json`),
   and let tray UIs (including third-party) wrap it. Smallest surface, no UI parity promise.
3. **Full cross-platform rewrite** (Electron/Tauri single codebase, macOS included) —
   rejected by default: it would discard a working native app for the sake of symmetry.

Shared constraints regardless of path:

- Transcript locations: `~/.claude/projects/` (Linux), `%USERPROFILE%\.claude\projects\` and
  WSL paths (Windows) — the scan location must stay configurable.
- retok needs python3 today; TF-0001 (native analyzer) is a natural prerequisite or
  companion, otherwise the dependency story on Windows gets worse.
- Local-first rules apply identically.

## Alternatives considered

- **WSL users run the macOS app?** — not possible; there is no equivalent. Doing nothing
  leaves non-Mac teammates with manual retok runs in a terminal, which is exactly the
  friction Tokfuel exists to remove.

## Progress

- [ ] Decide the approach (spike: tray-app skeleton on Windows + Linux reading real transcripts)
- [ ] Analyzer story on non-Mac (depends on [TF-0001](../TF-0001-native-swift-cost-analysis/TF-0001-native-swift-cost-analysis.md) or a portable equivalent)
- [ ] Distribution (winget / scoop, deb/rpm or AppImage) — separate follow-up items once real

## References

- Feedback thread (internal, 2026-07)
