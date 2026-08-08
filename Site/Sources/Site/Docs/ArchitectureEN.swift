import Ignite

struct ArchitectureEN: StaticPage {
    var path = "/docs/architecture"
    var title = "Architecture — Tokfuel"
    var description = "SPM layers (UI → Store → sources), UsageStore, and the per-source services."
    var layout: DocsLayout { DocsLayout(page: .architecture, language: .en) }

    var body: some HTML {
        VStack(alignment: .leading, spacing: 24) {
            Text("Architecture").docsTitle()

            Text("""
            Tokfuel is a SwiftUI menu-bar app with no server component. Every number \
            it shows comes from parsing files that Claude Code, Cursor, and Codex CLI \
            already keep on your Mac.
            """)
            .foregroundStyle(.secondary)

            Text("SPM layers").docsSubheading()

            Text("""
            App code under App/ is split into SPM targets. Dependencies flow \
            UI → Store → sources; the Tokfuel executable wires the concrete types.
            """)
            .foregroundStyle(.secondary)

            Section {
                Include("architecture.svg")
            }
            .class("tf-arch-diagram")

            List {
                ListItem {
                    Text {
                        Code("TokfuelUI")
                        " — popover, Settings, About, and other presentation"
                    }
                }
                ListItem {
                    Text {
                        Code("TokfuelStore")
                        " — aggregation and UI-facing shaping ("
                        Code("UsageStore")
                        ")"
                    }
                }
                ListItem {
                    Text {
                        Code("TokfuelClaude")
                        " / "
                        Code("TokfuelCursor")
                        " / "
                        Code("TokfuelCodex")
                        " / "
                        Code("TokfuelBudget")
                        " — fetch and domain sources"
                    }
                }
                ListItem {
                    Text {
                        Code("TokfuelSettings")
                        " / "
                        Code("TokfuelAnalytics")
                        " / "
                        Code("TokfuelCore")
                        " — settings, opt-in Analytics, shared types"
                    }
                }
            }

            Text {
                "Data flows fetch → shape / aggregate → present. The decision record is "
                Link("ADR-0002", target: "https://github.com/Tokfuel/Tokfuel/blob/main/ADR/0002-layer-spm-modules/0002-layer-spm-modules.md")
                "; the repository README has the same dependency diagram."
            }
            .foregroundStyle(.secondary)

            Text("UsageStore: the single source of truth").docsSubheading()

            Text("""
            UsageStore (in TokfuelStore) is the one @MainActor object every view reads \
            from. It owns the current cost totals, charts, and per-model breakdown, and \
            refreshes them on a timer — every 10 minutes when idle, stepping up to once \
            a minute for 5 minutes after cost moves. PopoverView and the rest of the UI \
            stay pure display layers; settings live separately in AppSettings, backed by \
            UserDefaults.
            """)
            .foregroundStyle(.secondary)

            Text("RetokService: reading Claude Code's own transcripts").docsSubheading()

            Text {
                "RetokService (in TokfuelClaude) shells out to the bundled "
                Link("retok", target: "https://github.com/Tokfuel/Tokfuel/blob/main/App/TokfuelClaude/Resources/README-retok.md")
                " script (© Daiki Matsudate, MIT, kept unmodified) to parse the "
                Code("~/.claude/projects/")
                " transcripts Claude Code writes on its own — no hooks, no extra "
                "install, nothing to configure. python3 is an optional dependency; "
                "without it, cost analysis degrades but the rest of the app keeps "
                "working."
            }
            .foregroundStyle(.secondary)

            Text("BudgetMonitor").docsSubheading()

            Text("""
            BudgetMonitor (in TokfuelBudget) watches UsageStore's totals against the \
            monthly and daily limits in AppSettings, and fires a heads-up exactly once \
            each time a threshold is crossed. The alert window itself is assembled by \
            the App / UI side.
            """)
            .foregroundStyle(.secondary)

            Text("Per-source services").docsSubheading()

            List {
                ListItem {
                    Text {
                        Code("CursorDashboardService")
                        " — when Cursor is installed and signed in, calls Cursor's own "
                        "dashboard usage API using the session token Cursor already "
                        "keeps in its local state.vscdb. Falls back to a local SQLite "
                        "token snapshot when signed out or offline."
                    }
                }
                ListItem {
                    Text {
                        Code("CursorPricingService")
                        " — fetches Cursor's own published price table once a day to "
                        "price fallback-path usage. Never guesses a rate for an unpriced "
                        "model; it's counted as $0 instead."
                    }
                }
                ListItem {
                    Text {
                        Code("ExchangeRateService")
                        " — fetches the USD→JPY rate from Frankfurter once a day, only "
                        "when JPY display is enabled."
                    }
                }
                ListItem {
                    Text {
                        Code("UpdateChecker")
                        " — polls GitHub Releases for a newer version at launch and "
                        "then every 24 hours; downloads only when you click Update."
                    }
                }
                ListItem {
                    Text {
                        Code("CSVExportService")
                        " — turns the current period's data already in the retok "
                        "report into daily or monthly CSV, entirely on-device."
                    }
                }
                ListItem {
                    Text {
                        Code("AnalyticsService")
                        " — the single surface for opt-in, distribution-build-only "
                        "Firebase Analytics events; a no-op everywhere else."
                    }
                }
            }

            Text("""
            Each source is kept independent and labeled — Cursor and Codex costs are \
            never silently merged into the Claude total.
            """)
            .foregroundStyle(.secondary)

            Text("The App/ tree").docsSubheading()

            Text("""
            Per ADR-0001, app-related trees live under App/. Site, Docs, and Scripts \
            stay outside. Verification artifacts sit in App/Tests/ beside the SPM \
            layer packages (App/Tokfuel*).
            """)
            .foregroundStyle(.secondary)

            List {
                ListItem {
                    Text {
                        Code("App/Tokfuel*")
                        " — executable and libraries (UI / Store / sources)"
                    }
                }
                ListItem {
                    Text {
                        Code("App/Tests/UnitTests")
                        " — what "
                        Code("swift test")
                        " runs"
                    }
                }
                ListItem {
                    Text {
                        Code("App/Tests/{IntegrationTests,E2E,TestDocs}")
                        " — integration, end-to-end, and scenario docs (see Testing)"
                    }
                }
            }

            Text("Related docs").docsSubheading()

            HStack(spacing: 16) {
                Link("ADR index", target: "\(sitePath)/docs/adr")
                    .linkStyle(.underline(.heavy))
                Link("Tests & verification", target: "\(sitePath)/docs/testing")
                    .linkStyle(.underline(.heavy))
                Link("Browse App/ on GitHub", target: "https://github.com/Tokfuel/Tokfuel/tree/main/App")
                    .linkStyle(.underline(.heavy))
            }
        }
        .frame(maxWidth: 720)
    }
}
