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
  <a href="https://tokfuel.github.io/Tokfuel/"><strong>Download for macOS</strong></a> ·
  <a href="README.md">English</a> ·
  <a href="README.ja.md">日本語</a>
</p>

---

<p align="center">
  <img src="assets/screenshot.png" alt="Popover screenshot" width="560"/>
</p>

## Features

- 💵 **Cost at a glance**

  Today's / period cost, daily and cumulative charts (with a budget reference line and a month-end pace estimate), per-model breakdown, top sessions, and retok's saving tips.

- 🖱️ **Cursor, too**

  If Cursor is installed and you're signed in, today's Cursor usage is folded into the
  same total and chart via Cursor's own dashboard API (using the session Cursor already
  keeps on disk — nothing to paste). Offline or signed-out, it falls back to local
  token snapshots (often a lower bound on Cursor 3.x). Pricing for the fallback path is
  refreshed once a day from Cursor's published price table.
  In Settings, choose combined / Claude only / Cursor only / side-by-side — the popover
  and menu bar both follow that choice (budget gauges still use the included sum).

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

  No telemetry. Network calls are: the opt-in exchange-rate fetch; if Cursor is
  installed, the daily price-table refresh; and, when signed into Cursor, a usage
  query to Cursor's dashboard API (auth + date range only — no prompts).
  Details: [Privacy Policy](docs/PRIVACY.md) · [Terms of Use](docs/TERMS.md).

## Install

1. Download `Tokfuel-x.y.z.dmg` from the [download page](https://tokfuel.github.io/Tokfuel/) or
   [Releases](https://github.com/akidon0000/Tokfuel/releases).
2. Open it and drag `Tokfuel.app` onto `Applications`.
3. Launch it — releases are signed with a Developer ID and notarized by Apple, so it opens
   with no Gatekeeper warning.

**Requirements**

- macOS 14 or later
- `python3` for the cost analysis (ships with the Xcode Command Line Tools)

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

### Contributors

<div id="contributors">
<!-- readme: contributors -start -->
<table>
	<tbody>
		<tr>
            <td align="center">
                <a href="https://github.com/akidon0000">
                    <img src="https://avatars.githubusercontent.com/u/53287375?v=4&s=100" width="100;" alt="akidon0000"/>
                    <br />
                    <sub><b>akidon0000</b></sub>
                </a>
            </td>
		</tr>
	</tbody>
</table>
<!-- readme: contributors -end -->
</div>

## Acknowledgements

- **Cost analysis** — [retok](https://github.com/d-date/retok), bundled unmodified.
  © [Daiki Matsudate (@d-date)](https://github.com/d-date), [MIT License](Tokfuel/Sources/Resources/LICENSE-retok).
- **App icon** — designed with [Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer);
  the source document lives in [Tokfuel/icon](https://github.com/Tokfuel/icon).
- **Exchange rates** — [Frankfurter](https://frankfurter.dev).
- **Roadmap conventions** — adapted from [bajutsu](https://github.com/bajutsu-e2e/bajutsu)'s issue-driven development workflow.

## License

[MIT](LICENSE) © [Dan Akiyama (@akidon0000)](https://github.com/akidon0000).
