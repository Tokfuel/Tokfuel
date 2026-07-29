# Tokfuel Privacy Policy

*Last updated: 2026-07-30*

This policy describes what data the Tokfuel macOS app reads, stores, and transmits. It is written for Tokfuel users and for App Store review.

## Summary

Tokfuel collects no personal data and sends no usage data anywhere. Everything it reads stays on your Mac. The app has no accounts, no tracking, no analytics, and no third-party SDKs.

## Data the app reads locally

To visualize your Claude Code usage, Tokfuel reads files that Claude Code already writes on your Mac:

- **Transcripts** under `~/.claude/projects/` — used to compute cost, token counts, and Skill / MCP / sub-agent activity.
- **Skills** under `~/.claude/skills/` — used to show your skill inventory.

All processing happens on your device. Derived data (aggregates, settings, notification state) is stored only in `~/Library/Application Support/Tokfuel/` and in the app's user defaults. None of it is transmitted.

## The one network request

Tokfuel makes exactly one kind of network request, and only if you opt in: when you switch the display currency to JPY, the app fetches the daily USD→JPY exchange rate from the [Frankfurter API](https://frankfurter.dev) (`api.frankfurter.dev`), at most once per day.

- The request asks only for the exchange rate; it carries no usage data, no identifiers, and no content from your Mac.
- As with any web request, the API operator technically sees standard connection metadata such as your IP address. See the [Frankfurter website](https://frankfurter.dev) for its terms.
- With the currency left at USD (the default), the app makes no network requests at all.

## What Tokfuel does not do

- No accounts or sign-in.
- No telemetry, analytics, or crash reporting.
- No advertising or tracking.
- No third-party SDKs (the bundled [retok](https://github.com/d-date/retok) script runs locally).

## Changes to this policy

This policy lives in the [Tokfuel repository](https://github.com/Tokfuel/Tokfuel); any change is visible in its git history. If a future version of the app collects any data (for example, opt-in analytics), this policy will be revised in the same release that introduces the collection.

## Contact

Questions or concerns: open an issue at <https://github.com/Tokfuel/Tokfuel/issues>.
