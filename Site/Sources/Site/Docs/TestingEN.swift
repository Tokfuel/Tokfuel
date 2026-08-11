import Ignite

struct TestingEN: StaticPage {
    var path = "/docs/testing"
    var title = "Tests & verification — Tokfuel"
    var description = "App/Tests layout, what UnitTests cover, verification gates, CI, and UI-preview rules — on this site."
    var layout: DocsLayout { DocsLayout(page: .testing, language: .en) }

    var body: some HTML {
        VStack(alignment: .leading, spacing: 24) {
            Text("Tests & verification").docsTitle()

            Text("""
            All app verification artifacts live under App/Tests/ (ADR-0001). Unit tests \
            that run, plus Integration / E2E / TestDocs boxes, share one parent so the \
            product tree (App/Tokfuel*) stays separate from ops trees (Site / Docs / \
            Scripts). This page carries that layout and how verification is meant to work.
            """)
            .foregroundStyle(.secondary)

            Text("Directory layout").docsSubheading()

            CodeBlock {
                """
                App/Tests/
                  UnitTests/          … Swift Testing; what swift test runs
                  IntegrationTests/   … integration (placeholder for now)
                  E2E/                … end-to-end implementations (not under swift test)
                  TestDocs/           … scenario design (documents, not runnable)
                  README.md           … parent-directory note
                """
            }

            Text("UnitTests").fontWeight(.bold)

            Text("""
            Put headless-checkable logic here. TokfuelTests in Package.swift points at \
            this path; swift test runs it. When you add logic, add tests next to that layer.
            """)
            .foregroundStyle(.secondary)

            Text("Do not write tests that touch real user state under ~/Library/Application Support/Tokfuel.")
                .foregroundStyle(.secondary)

            CoverageChart(language: .en)

            Text("IntegrationTests").fontWeight(.bold)

            Text("""
            Placeholder for integration tests (README only today). When you add some, \
            use a separate test target or an explicit Package.swift entry — do not dump \
            them into the default UnitTests path.
            """)
            .foregroundStyle(.secondary)

            Text("E2E").fontWeight(.bold)

            Text("""
            Home for end-to-end implementations. Not part of swift test; a separate runner \
            is expected. Do not bring in mobile stacks like Maestro or Appium. Add only \
            what a macOS menu-bar app needs (launch smoke, screen reach) as later Issues \
            require. Scenario design stays canonical in TestDocs.
            """)
            .foregroundStyle(.secondary)

            Text("TestDocs").fontWeight(.bold)

            Text("""
            Scenario design documents — not runnable code. Keep coverage viewpoints here; \
            progress is ticket → implement → update status. Templates, viewpoint IDs, and \
            individual scenarios land in later Issues; the directory box is reserved first.
            """)
            .foregroundStyle(.secondary)

            Text("What UnitTests cover").docsSubheading()

            Text("Store / aggregation & display shaping").fontWeight(.bold)
            List {
                ListItem { Text("UsageStore — totals, charts, per-model breakdown, refresh") }
                ListItem { Text("CostChart / CostDisplayMode / Formatting — display shaping and modes") }
                ListItem { Text("MenuBarReadout / MenuBarImage — menu-bar text and rendering") }
                ListItem { Text("RefreshScheduler — idle vs active refresh intervals") }
            }

            Text("Claude (retok)").fontWeight(.bold)
            List {
                ListItem { Text("RetokReport — report decoding") }
                ListItem { Text("TranscriptScanner — transcript scanning") }
                ListItem { Text("AdvicePrompt — saving-tip prompts") }
            }

            Text("Cursor / Codex").fontWeight(.bold)
            List {
                ListItem { Text("CursorDashboardService / CursorPricing / CursorPricingService — dashboard fetch and price table") }
                ListItem { Text("CursorCostDriver / CursorAdvice — cost estimate and advice") }
                ListItem { Text("CodexCostDriver — cost from Codex CLI sessions") }
            }

            Text("Budget / Settings / other").fontWeight(.bold)
            List {
                ListItem { Text("BudgetMonitor — monthly / daily thresholds and once-per-level alerts") }
                ListItem { Text("AppSettings — UserDefaults-backed settings") }
                ListItem { Text("CSVExportService — on-device CSV export") }
                ListItem { Text("UpdateChecker — Releases polling and download boundary") }
                ListItem { Text("HTTPClient / RemoteDiagnosticsPolicy / UsageEventLog — networking and diagnostics policy") }
                ListItem { Text("ScreenshotRenderer — fixture screens for ui-preview") }
            }

            Text("Local verification gates").docsSubheading()

            List {
                ListItem {
                    Text {
                        Code("swift test")
                        " — runs App/Tests/UnitTests. Baseline gate before a PR."
                    }
                }
                ListItem {
                    Text {
                        Code("swift build -c release")
                        " — release build close to what Scripts/build.sh packages."
                    }
                }
                ListItem {
                    Text {
                        Code("bash Scripts/build.sh")
                        " — installs Tokfuel.app into /Applications and launches it for runtime observation. "
                        "Do not claim unverified behavior works."
                    }
                }
            }

            Text("CI").docsSubheading()

            Text("""
            .github/workflows/ci.yml runs unit tests on PRs that touch App/Tokfuel, \
            App/Tests, Package.swift, and related paths. Docs / Site-only changes skip \
            that job. Release packaging is checked via Scripts/build.sh and the \
            distribution flow.
            """)
            .foregroundStyle(.secondary)

            Text("UI preview (screenshots)").docsSubheading()

            Text("""
            Keep new UI visible to reviewers. When you add or change PopoverView, \
            SettingsView, AboutView, or any new standalone View (consent dialogs, alerts, \
            …), update the following in the same PR:
            """)
            .foregroundStyle(.secondary)

            List {
                ListItem { Text("ScreenshotRenderer.allScreens() fixtures") }
                ListItem { Text("ORDER / screen_title lists in ui-preview.yml") }
            }

            Text("""
            PRs labeled ui-preview can render those states. Views only reachable through \
            live singletons (network responses, real install paths) need injectable \
            fixtures (see UpdateChecker.preview). Put dialog copy in a SwiftUI view shared \
            by runtime and preview.
            """)
            .foregroundStyle(.secondary)

            Text("How coverage is chosen").docsSubheading()

            Text("""
            Prefer UnitTests for logic that can be checked headlessly. Looks and reachability \
            are covered by ui-preview (VRT-like) and E2E only where needed. Write “what we \
            guarantee” in TestDocs, then implement in UnitTests / IntegrationTests / E2E.
            """)
            .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Link("ADR-0001 (this site)", target: "\(sitePath)/docs/adr")
                    .linkStyle(.underline(.heavy))
                Link("Architecture", target: "\(sitePath)/docs/architecture")
                    .linkStyle(.underline(.heavy))
                Link("App/Tests/ (git)", target: "https://github.com/Tokfuel/Tokfuel/tree/main/App/Tests")
                    .linkStyle(.underline(.heavy))
            }
        }
        .frame(maxWidth: 720)
    }
}
