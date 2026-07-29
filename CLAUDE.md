# CLAUDE.md — working agreement for AI sessions

> The shared premise every session (human or agent) starts from. Read this first.
> Human contributors start from [`CONTRIBUTING.md`](CONTRIBUTING.md); the feature
> plan lives in [GitHub Issues](https://github.com/Tokfuel/Tokfuel/issues) (TF-NNNN items).

## What this is

**Tokfuel** is a native SwiftUI macOS menu-bar app that visualizes local Claude
Code usage — cost (via a bundled copy of [retok](https://github.com/d-date/retok)), Skill / MCP /
sub-agent activity, a skill inventory, and budget alerts — with zero setup: it reads the
transcripts Claude Code already writes under `~/.claude/projects/`. All sources live in
[`Tokfuel/Sources/`](Tokfuel/Sources/); see the README
[Architecture](README.md#-architecture) section for the file map.

## Ground rules (do not violate)

1. **Local-only.** Collected data never leaves the Mac — no telemetry, no network sends.
   Sole exception: when the user opts into JPY display, `ExchangeRateService` fetches a daily
   USD→JPY rate from the Frankfurter API (the request carries no usage data).
2. **Zero setup stays zero.** The app reads Claude Code transcripts directly. Never require
   hooks, external installs, or Claude Code configuration for a feature to work.
3. **retok is vendored unmodified.** `Sources/Resources/retok.py` + `locales/` are
   © Daiki Matsudate, MIT — never edit them in place (send an upstream PR instead), and keep
   `LICENSE-retok` + the in-app attribution intact. Provenance and the update procedure are in
   [`README-retok.md`](Tokfuel/Sources/Resources/README-retok.md).
4. **python3 is an optional dependency.** Only the Cost tab needs it; everything else must keep
   working when it is absent (the Cost tab shows an error and degrades gracefully).
5. **No new package dependencies.** Swift 6 / SwiftUI / macOS 14+, standard SDK only —
   staying dependency-free keeps the app trivial to build.

## Verify your work (the gate)

```bash
swift test               # unit tests (Tokfuel/Tests, Swift Testing)
swift build -c release   # the config scripts/build.sh packages
```

CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs the tests and the release build on every PR. For runtime-visible changes, install and observe the real app:
`bash scripts/build.sh` packages `Tokfuel.app` into `/Applications` and launches it (use the built-in
`verify` skill rather than claiming untested behavior works). Headless-testable logic
(e.g. `BudgetMonitor`, `RetokReport` decoding) lives in `Tokfuel/Tests` — add tests there for
new logic. Avoid tests that touch real user state (`~/Library/Application Support/Tokfuel`).

## Roadmap workflow

Features are tracked as GitHub Issues in [Tokfuel/Tokfuel](https://github.com/Tokfuel/Tokfuel/issues).
Use the **Proposal** issue template for new features and the **Bug report** template for bugs.
The roadmap is also visible as [GitHub Project #1](https://github.com/orgs/Tokfuel/projects/1).

The skills under [`.claude/skills/`](.claude/skills/) drive the cycle:

- **`ideation`** — shape an idea into a GitHub Issue (authoring only).
- **`implement-tf`** — ship an issue from its number (issue body = spec).
- **`task-select`** — survey open issues and pick the next item to implement.

## Conventions

- One topic per branch (`claude/<short-topic>`), small focused PRs.
- Commits: imperative subject < 72 chars; body says *why*. Roadmap-implementing PRs prefix the
  title `[TF-NNNN]`.
- UI state on `@MainActor`; `UsageStore` stays the single source of truth, `PopoverView` stays
  pure presentation; settings live in `AppSettings` (UserDefaults-backed).
- Docs are bilingual: user-visible changes update `README.md` **and** `README.ja.md`.
</content>
