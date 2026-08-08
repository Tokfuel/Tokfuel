import Ignite

struct PrivacyOverviewEN: StaticPage {
    var path = "/docs/privacy"
    var title = "Privacy & network policy — Tokfuel"
    var description = "Tokfuel is local-only. Here's the full list of the few requests it makes and why."
    var layout: DocsLayout { DocsLayout(page: .privacy, language: .en) }

    var body: some HTML {
        VStack(spacing: 24) {
            Text("Privacy & network policy").docsTitle()

            Text("""
            Tokfuel never sends usage data — prompts, transcripts, costs, or paths — \
            from Claude Code, Cursor, or Codex CLI off your Mac. That rule has exactly \
            the exceptions below, and nothing else.
            """)
            .foregroundStyle(.secondary)

            List {
                ListItem {
                    Text {
                        Code("ExchangeRateService")
                        " — once a day, only if you enable JPY display, fetches the "
                        "USD→JPY rate from "
                        Link("Frankfurter", target: "https://frankfurter.dev")
                        ". No usage data in the request."
                    }
                }
                ListItem {
                    Text {
                        Code("CursorPricingService")
                        " — once a day, if Cursor is detected on your Mac, fetches "
                        "Cursor's own published price table to correct Cursor cost "
                        "estimates. No usage data is sent; unpriced models are counted "
                        "as $0 rather than guessed."
                    }
                }
                ListItem {
                    Text {
                        Code("CursorDashboardService")
                        " — if Cursor is installed and you're signed in, calls Cursor's "
                        "own dashboard usage API using the session token Cursor already "
                        "keeps locally. Only an auth header and a date range are sent — "
                        "never prompts or transcripts. Falls back to a local SQLite "
                        "token snapshot on failure."
                    }
                }
                ListItem {
                    Text {
                        Code("UpdateChecker")
                        " — polls the public GitHub Releases API at launch and hourly "
                        "to detect a new version. The release asset itself only "
                        "downloads when you click Update in the popover. No usage data, "
                        "transcripts, or identifiers in these requests."
                    }
                }
                ListItem {
                    Text("""
                    Crash reporting via Firebase Crashlytics — distribution builds \
                    only, no consent prompt, no prompts or costs included. \
                    Development builds never configure Firebase.
                    """)
                }
                ListItem {
                    Text("""
                    Anonymous Firebase Analytics for app-UI events — distribution \
                    builds and opt-in only, off by default.
                    """)
                }
            }

            Text("""
            Everything else — cost analysis, budgets, charts, CSV export — runs \
            entirely on-device by reading files Claude Code, Cursor, and Codex CLI \
            already keep on your Mac.
            """)
            .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Link("Privacy Policy", target: "https://github.com/Tokfuel/Tokfuel/blob/main/Docs/PRIVACY.md")
                    .linkStyle(.underline(.heavy))
                Link("Terms of Use", target: "https://github.com/Tokfuel/Tokfuel/blob/main/Docs/TERMS.md")
                    .linkStyle(.underline(.heavy))
            }
        }
        .frame(maxWidth: 720)
    }
}
