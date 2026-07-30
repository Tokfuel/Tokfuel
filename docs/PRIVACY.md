# Tokfuel Privacy Policy

*Last updated: 2026-07-31*

This policy describes what data the Tokfuel macOS app reads, stores, and transmits. It is written for Tokfuel users and for App Store review.

## Summary

<<<<<<< HEAD
Tokfuel collects no personal data and sends no usage data anywhere. Everything it reads — your Claude Code transcripts and Skill inventory — stays on your Mac. The app has no accounts, no tracking, no analytics, and no third-party SDKs. It makes a small number of narrow, disclosed network requests (see below) to fetch exchange rates, to check GitHub Releases for a newer app version, and, if you use Cursor, to fetch Cursor's own price table and usage totals — never your usage data.
=======
Tokfuel collects no personal data and sends no prompts or local transcripts anywhere. Everything it reads from Claude Code stays on your Mac. The app has no accounts, no tracking, no analytics, and no third-party SDKs. It makes a small number of narrow, disclosed network requests (see below) to fetch exchange rates and, if you use Cursor, Cursor's own price table and dashboard usage totals.
>>>>>>> origin/main

## Data the app reads locally

To visualize your Claude Code usage, Tokfuel reads files that Claude Code already writes on your Mac:

- **Transcripts** under `~/.claude/projects/` — used locally to compute Claude Code cost, prompt count, and session count.
- **Cursor's local token database** (`~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`), if Cursor is installed — used to estimate Cursor cost. This file is read locally; see below for the one case where a derived value (auth token, date range) leaves the Mac.
- **Codex CLI session logs** under `~/.codex/sessions/`, if present — read on-device (via the bundled retok script) to estimate Codex cost, alongside session and token counts. This is a separate cost estimate, not merged into your Claude total.

All processing happens on your device. Derived data (aggregates, settings, notification state) is stored only in `~/Library/Application Support/Tokfuel/` and in the app's user defaults. None of it is transmitted.

Tokfuel currently reads only Claude Code's, Cursor's, and Codex's local files. If a future version adds support for other AI coding tools, it will read those tools' local files the same way — on-device only — and this policy will be updated to name them.

## Network requests

Tokfuel makes network requests only in these cases, and never sends your Claude Code transcripts or prompts:

- **Exchange rate (opt-in).** When you switch the display currency to JPY, the app fetches the daily USD→JPY rate from the [Frankfurter API](https://frankfurter.dev) (`api.frankfurter.dev`), at most once per day. The request carries no usage data, no identifiers, and no content from your Mac. With the currency left at USD (the default), this request never happens.
- **App update check (automatic).** Once at launch and every 24 hours, `UpdateChecker` asks the public GitHub Releases API (`api.github.com`) for the latest Tokfuel release, so the app can offer an in-app update. The request carries no usage data and no identifiers. The release file itself is downloaded from GitHub only when you click the **Update** button next to the popover's ⋯ menu.
- **Cursor price table (automatic, if Cursor is detected).** To refine Cursor cost estimates, `CursorPricingService` fetches Cursor's own published price table from `cursor.com/docs/models-and-pricing` once a day. This is a page fetch only — no usage data is sent.
- **Cursor dashboard usage (if Cursor is installed and you're signed in).** `CursorDashboardService` calls Cursor's dashboard usage API (`api2.cursor.sh`) using the session token already stored locally in Cursor's own `state.vscdb`. The request carries only that auth header and a date range — no prompts, no local transcripts. On any failure it falls back to local SQLite token snapshots instead.

As with any web request, the operators of these APIs technically see standard connection metadata such as your IP address. If Cursor is not installed, the only requests that can occur are the update check, the release download you explicitly trigger from the Update button, and the exchange-rate request (if you opt into JPY).

## What Tokfuel does not do

- No accounts or sign-in.
- No telemetry, analytics, or crash reporting.
- No advertising or tracking.
- No third-party SDKs (the bundled [retok](https://github.com/d-date/retok) script runs locally).

## Changes to this policy

This policy lives in the [Tokfuel repository](https://github.com/Tokfuel/Tokfuel); any change is visible in its git history. If a future version of the app collects any data (for example, opt-in analytics), this policy will be revised in the same release that introduces the collection.

## Contact

Questions or concerns: <akidon0000@gmail.com>, or open an issue at <https://github.com/Tokfuel/Tokfuel/issues>.
