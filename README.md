<p align="center">
  <img src="assets/banner.svg" alt="Tokfuel" width="100%"/>
</p>

<h1 align="center">Tokfuel</h1>

<p align="center">
  <strong>See what AI coding costs you — from the menu bar.</strong>
</p>

<p align="center">
  A tiny SwiftUI menu-bar app (⛽️) for macOS.<br/>
  It reads the transcripts Claude Code already writes under <code>~/.claude/projects/</code><br/>
  and shows today's and period cost. Zero setup — everything stays on your Mac.
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
  <img src="assets/screenshot.png" alt="Popover screenshot" width="560"/>
</p>

## Features

- 💵 **Cost at a glance**

  Today's / period cost, daily chart, per-model breakdown, top sessions, and retok's saving tips.

- 🚨 **Budgets**

  Independent monthly and daily limits.
  Near a limit the ⛽️ icon turns orange; over it, red — with a notification.

- 📊 **Menu-bar readout**

  Pick a metric (today, this month, both, prompts) and how to show it
  (amount, percent, ring gauge, ring + percent, icon only) — or the *remaining* budget.
  Percent and gauges measure against your budget limit or your 30-day daily average.
  The gauge is either a ring (beside the ⛽️ icon or replacing it) or the ⛽️ icon itself
  filling bottom-up like a fuel tank — blue inside budget, orange at the threshold, red over.
  Today and this month are coloured independently. Live previews in Settings.

- 💱 **USD or JPY**

  Budgets and all amounts switch currency.
  Daily rate via [Frankfurter](https://frankfurter.dev).

- 🔒 **Local-first**

  No telemetry. The only network call is the opt-in exchange-rate fetch.

## Install

1. Download `Tokfuel-x.y.z.zip` from [Releases](https://github.com/akidon0000/Tokfuel/releases).
2. Unzip it and drag `Tokfuel.app` into `/Applications`.
3. First launch: right-click the app → **Open**
   (or allow it in **System Settings → Privacy & Security**).

> [!NOTE]
> The Gatekeeper warning appears because the app is ad-hoc signed.
> Downloading with `curl` instead of a browser skips the warning entirely.

**Requirements**

- macOS 14 or later

**Build from source**

```bash
git clone https://github.com/akidon0000/Tokfuel.git
cd Tokfuel
bash scripts/build.sh
```

## Contributing

PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

- Tests: `swift test`
- Roadmap: [GitHub Issues](https://github.com/Tokfuel/Tokfuel/issues)
- Found a vulnerability? Report it privately — see [SECURITY.md](SECURITY.md).

## Acknowledgements

- **Cost analysis** — a native Swift port of [retok](https://github.com/d-date/retok)
  (the original script and locale data are bundled unmodified as the reference).
  © [Daiki Matsudate (@d-date)](https://github.com/d-date), [MIT License](Tokfuel/Sources/Resources/LICENSE-retok).
- **App icon** — designed with [Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer);
  the source document lives in [Tokfuel/icon](https://github.com/Tokfuel/icon).
- **Exchange rates** — [Frankfurter](https://frankfurter.dev).
- **Roadmap conventions** — adapted from [bajutsu](https://github.com/bajutsu-e2e/bajutsu)'s issue-driven development workflow.

## License

[MIT](LICENSE) © [Dan Akiyama (@akidon0000)](https://github.com/akidon0000).
