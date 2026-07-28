<p align="center">
  <img src="assets/banner.svg" alt="Tokfuel" width="100%"/>
</p>

<h1 align="center">Tokfuel</h1>

<p align="center">
  <strong>See what Claude Code costs you — from the menu bar.</strong><br/>
  A tiny SwiftUI menu-bar app (⛽️) that reads the transcripts Claude Code already writes under <code>~/.claude/projects/</code> and shows today's and period cost. Zero setup, zero telemetry — everything stays on your Mac.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-1B1B1F?style=flat-square&logo=apple"/>
  <a href="https://github.com/akidon0000/Tokfuel/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/akidon0000/Tokfuel/actions/workflows/ci.yml/badge.svg"/></a>
  <a href="https://github.com/akidon0000/Tokfuel/releases"><img alt="Release" src="https://img.shields.io/github/v/release/akidon0000/Tokfuel?style=flat-square"/></a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.ja.md">日本語</a>
</p>

---

<p align="center">
  <img src="assets/screenshot.svg" alt="Popover screenshot" width="560"/>
</p>

## Features

- 💵 Today's / period cost, daily cost chart, per-model breakdown, most expensive sessions, and retok's saving tips
- 🚨 Independent **monthly and daily budget limits** — the ⛽️ icon turns orange near a limit, red over it, with a notification
- 📊 Menu bar shows today's cost, this month's, or both (configurable, with live previews)
- 💱 Display in USD or JPY (daily exchange rate via [Frankfurter](https://frankfurter.dev))
- 🔒 Local-first — no telemetry; the only network call is the opt-in JPY exchange-rate fetch

## Install

Download `Tokfuel-x.y.z.zip` from [Releases](https://github.com/akidon0000/Tokfuel/releases), unzip, and drag `Tokfuel.app` into `/Applications`.

The app is ad-hoc signed, so Gatekeeper blocks the first launch: right-click → **Open**, or allow it in **System Settings → Privacy & Security**.

Requirements: macOS 14+, and `python3` (ships with Xcode Command Line Tools) for the cost analysis.

To build from source instead:

```bash
git clone https://github.com/akidon0000/Tokfuel.git && cd Tokfuel && ./build.sh
```

## Contributing

PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Tests: `swift test`. The roadmap lives in [`roadmaps/`](roadmaps/README.md).

## Acknowledgements

Cost analysis is powered by a bundled, unmodified copy of **[retok](https://github.com/d-date/retok)** — © [Daiki Matsudate (@d-date)](https://github.com/d-date), [MIT License](Tokfuel/Sources/Resources/LICENSE-retok). Provenance and the update procedure are in [README-retok.md](Tokfuel/Sources/Resources/README-retok.md).

## License

[MIT](LICENSE) © akidon0000 — except the bundled retok (see above).
