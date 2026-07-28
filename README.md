<p align="center">
  <img src="assets/banner.svg" alt="Tokfuel" width="100%"/>
</p>

<h1 align="center">Tokfuel</h1>

<p align="center">
  <strong>See what Claude Code costs you — from the menu bar.</strong><br/>
  A tiny, native SwiftUI menu-bar app (⛽️) that reads your local Claude Code usage logs and shows today's and period cost at a glance.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-1B1B1F?style=flat-square&logo=apple"/>
  <img alt="Language" src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white"/>
  <img alt="UI" src="https://img.shields.io/badge/SwiftUI-NSStatusItem-D97757?style=flat-square"/>
  <img alt="License" src="https://img.shields.io/badge/License-MIT-2E2018?style=flat-square"/>
  <img alt="PRs" src="https://img.shields.io/badge/PRs-welcome-E8927C?style=flat-square"/>
  <a href="https://github.com/akidon0000/tokfuel/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/akidon0000/tokfuel/actions/workflows/ci.yml/badge.svg"/></a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.ja.md">日本語</a>
</p>

---

<p align="center">
  <img src="assets/screenshot.svg" alt="Popover screenshot" width="560"/>
</p>

## ✨ Why?

Claude Code quietly accumulates a lot of usage signal — most importantly, how much each session costs — but that data just sits in transcript files under `~/.claude/projects/`. **Tokfuel** surfaces your cost with **zero setup**: install the app and it reads the transcripts directly. No hooks, no CLI install, no servers, no telemetry — everything stays on your Mac. The current release is an intentionally minimal **cost-only MVP**; the fuel-pump icon in the menu bar tells you how much fuel you've burned today.

Cost analysis is powered by a bundled copy of [retok](https://github.com/d-date/retok) by [Daiki Matsudate (@d-date)](https://github.com/d-date) — a token-efficiency analyzer for Claude Code logs (MIT License, see [Acknowledgements](#-acknowledgements--third-party-licenses)).

## 🚀 Features

- 💵 **Cost view (via retok)** — today's / period cost in the menu bar and popover, cache-hit rate, cost per prompt, daily cost chart, per-model breakdown, most expensive sessions, and retok's actionable recommendations (cache TTL misses, oversized contexts, retry loops, …).
- ⛽️ **Fuel-pump menu-bar icon** — a `fuelpump.fill` icon that shows today's estimated cost next to it, and changes color with your budget status.
- ⚙️ **Zero setup** — scans `~/.claude/projects/` transcripts directly (with an incremental cache) and registers itself as a login item. Install and forget.
- 🛠️ **Settings** — launch-at-login, menu-bar display (today's cost / this month's cost / both / prompt count / icon only, with live previews), default period, report language, and the **Claude directory** location so it works on any machine layout.
- 🚨 **Budget alerts** — set independent **monthly** (rolling 30 days or calendar month) and **daily** spending limits (USD). At a configurable threshold (70/80/90%) the menu-bar icon turns orange and a notification fires; over either limit it turns red. The popover shows a budget progress bar per limit with the threshold marker.
- 📊 **Menu-bar resident** — shows today's estimated cost right in the menu bar, no Dock clutter (`LSUIElement = YES`), auto-refreshes every 10 minutes.
- 🪞 **Self-instrumentation** — Tokfuel records its *own* UI events (popover opens, setting changes — never transcript content, project names, or costs) to a local JSONL under `~/Library/Application Support/Tokfuel/events/`, as evidence for future improvement decisions. On by default because it never leaves the Mac; Settings can view, disable, or erase it.
- 🔒 **100% local** — nothing leaves your machine.

## 🧰 Requirements

- macOS **14.0** Sonoma or later
- Xcode **16+** / Swift **6.0** toolchain (to build)
- `python3` (ships with Xcode Command Line Tools) — used to run the bundled retok for cost analysis; without it the app shows an error in place of the cost report

## 📦 Install

### Option 1: Download a release (recommended)

Grab `Tokfuel-x.y.z.zip` from the [Releases page](https://github.com/akidon0000/tokfuel/releases), unzip it, and drag `Tokfuel.app` into `/Applications`. The binary is universal (Apple Silicon & Intel); retok is bundled inside — nothing else to install.

Because the app is ad-hoc signed (no paid Apple Developer ID), the first launch is blocked by Gatekeeper. Right-click the app and choose **Open**, or allow it under **System Settings → Privacy & Security → Open Anyway**. Alternatively:

```bash
xattr -d com.apple.quarantine /Applications/Tokfuel.app
```

### Option 2: Build & install with the script

```bash
git clone https://github.com/akidon0000/tokfuel.git
cd tokfuel

./build.sh
```

`build.sh` runs a release build, packages a `Tokfuel.app` bundle into `/Applications`, ad-hoc signs it, and launches it.

### Option 3: Run from source

```bash
swift run -c release
```

> [!NOTE]
> The app is **ad-hoc signed** (`codesign --sign -`). On first launch macOS may warn that the developer can't be verified — right-click the app and choose **Open**, or allow it in **System Settings → Privacy & Security**.

## 🖱 Usage

1. The menu bar shows **today's estimated cost** next to the ⛽️ icon at all times; click it to open the popover.
2. The popover shows period totals (Today / 7d / 30d), cache-hit rate, daily cost chart, per-model costs, retok recommendations (tap to expand), and the most expensive sessions. A persistent "Today" line under the header shows today's cost, prompts, and sessions.
3. Hit **↻** to rescan, **⚙** for settings, or **⊗** to quit. Data auto-refreshes every 10 minutes anyway.

## 🗂 Data source

Everything is derived from the transcripts Claude Code already writes — no hooks or extra configuration:

```
~/.claude/projects/
└── <project-dir>/
    └── <session>.jsonl   # scanned for tool_use (Skill / mcp__* / Agent) and prompts
```

- The Swift scanner counts Skill / MCP / sub-agent calls and prompts per repo per day, with a per-file incremental cache in `~/Library/Application Support/Tokfuel/` so rescans are fast.
- The bundled [retok](https://github.com/d-date/retok) script analyzes the same transcripts for token usage, cost estimates, cache efficiency, and recommendations (`retok --json`).
- The **Claude directory** (`~/.claude`) is configurable in Settings, so non-standard layouts work too.

## 🏗 Architecture

```
Tokfuel/Sources/
├── App.swift                # @main, AppDelegate, NSStatusItem + NSPopover, login item, refresh timer
├── PopoverView.swift        # SwiftUI popover: cost-only MVP view
├── UsageStore.swift         # ObservableObject: aggregates scanner + retok results
├── TranscriptScanner.swift  # scans ~/.claude/projects JSONL for tool usage (incremental cache)
├── RetokService.swift       # runs the bundled retok via python3, decodes the JSON report
├── AppSettings.swift        # UserDefaults-backed settings (login item, display, period, language)
├── SettingsView.swift       # SwiftUI settings window
└── Resources/
    ├── retok.py             # vendored, unmodified copy of d-date/retok (© Daiki Matsudate, MIT)
    ├── locales/             # retok translations (recommendations follow your locale)
    ├── LICENSE-retok        # retok's MIT license text (ships inside the app)
    └── README-retok.md      # provenance: upstream repo, vendored commit, update procedure
```

- `UsageStore` is the single source of truth: it merges the transcript scan and the retok report and publishes them.
- `PopoverView` is pure presentation, driven by the store.
- `AppDelegate` owns the status item and popover lifecycle; the app runs as an accessory (no Dock icon) and registers itself as a login item.

## 🤝 Contributing

PRs welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for dev setup, coding style, and the PR checklist.

Planned and shipped features are tracked as **CU items** in [`roadmaps/`](roadmaps/README.md)
(bilingual, Swift-Evolution-style proposals — a convention adapted from
[bajutsu](https://github.com/bajutsu-e2e/bajutsu)). The Proposals table and "Unsorted ideas" there
are the up-to-date backlog; a few starters:

- A time-range filter (today / this week / all time).
- Edit-metrics (added / deleted lines) visualization — the data is already decoded.
- [CU-0002](roadmaps/CU-0002-native-swift-cost-analysis/CU-0002-native-swift-cost-analysis.md) — native Swift cost analysis (drops the python3 dependency).

## 🙏 Acknowledgements / Third-party licenses

This app bundles **[retok](https://github.com/d-date/retok)** — © [Daiki Matsudate (@d-date)](https://github.com/d-date), released under the [MIT License](Tokfuel/Sources/Resources/LICENSE-retok). The vendored copy is unmodified (only the filename differs: `retok` → `retok.py`); its license text ships inside the app bundle, and provenance (upstream commit, update procedure) is documented in [README-retok.md](Tokfuel/Sources/Resources/README-retok.md). All cost estimation, cache-efficiency analysis, and recommendations in the app are retok's work.

## 📄 License

[MIT](LICENSE) © akidon0000 — except the bundled retok (see above).
