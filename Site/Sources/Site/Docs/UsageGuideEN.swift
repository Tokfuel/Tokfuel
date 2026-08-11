import Ignite

struct UsageGuideEN: StaticPage {
    var path = "/docs/usage"
    var title = "Usage guide — Tokfuel"
    var description = "How to install Tokfuel and read what it shows you."
    var layout: DocsLayout { DocsLayout(page: .usage, language: .en) }

    var body: some HTML {
        VStack(alignment: .leading, spacing: 24) {
            Text("Usage guide").docsTitle()

            Text("Install").docsSubheading()

            List {
                ListItem {
                    Text {
                        "Download "
                        Link("Tokfuel-x.y.z.dmg", target: "https://github.com/Tokfuel/Tokfuel/releases/latest")
                        " from the download page or GitHub Releases."
                    }
                }
                ListItem { Text("Open it and drag Tokfuel.app onto Applications.") }
                ListItem {
                    Text("""
                    Launch it — releases are signed with a Developer ID and notarized \
                    by Apple, so it opens with no Gatekeeper warning.
                    """)
                }
            }
            .listMarkerStyle(.ordered)

            Text("""
            Requires macOS 14 or later, plus python3 for the cost analysis (already \
            included with the Xcode Command Line Tools). Without python3, cost \
            analysis degrades gracefully — everything else keeps working.
            """)
            .foregroundStyle(.secondary)

            Text("Reading the menu bar").docsSubheading()

            Text("""
            The ⛽️ icon shows today's or this month's cost, a percent, or a ring \
            gauge — pick which in Settings. It turns orange near a budget limit and \
            red once you're over it. Click it to open the popover: current cost, a \
            daily chart for today / this week / this month / this year, a per-model \
            breakdown, top sessions, and saving tips (from retok's Claude analysis \
            plus Cursor-derived ones).
            """)
            .foregroundStyle(.secondary)

            Text("Budgets").docsSubheading()

            Text("""
            Set independent monthly and daily limits in Settings. Near a limit you \
            get a heads-up — a notification, a floating alert window, or both — fired \
            once when the level rises.
            """)
            .foregroundStyle(.secondary)

            Text("Cursor and Codex").docsSubheading()

            Text("""
            If Cursor is installed and you're signed in, today's Cursor usage folds \
            into the same total and chart via Cursor's own dashboard API. Signed out \
            or offline, it falls back to local token snapshots and says so, so a $0 \
            figure is never mistaken for "no usage". If Codex CLI has local session \
            logs, its cost shows as its own color in the daily chart — never merged \
            into the Claude total. In Settings, choose combined / Claude only / \
            Cursor only / Codex only / side-by-side.
            """)
            .foregroundStyle(.secondary)

            Text("Exporting usage").docsSubheading()

            Text("""
            The popover's ⋯ menu has daily and monthly CSV export for the currently \
            shown period, each with period totals and a per-model cost breakdown — \
            useful for an admin collecting a team's spend by hand. Nothing is sent \
            anywhere on its own.
            """)
            .foregroundStyle(.secondary)

            Text("Settings you’ll touch most").docsSubheading()

            List {
                ListItem {
                    Text("Menu bar — today’s / this month’s amount, a percent, or a ring gauge.")
                }
                ListItem {
                    Text("Budgets — monthly and daily caps, plus notification / floating alert style.")
                }
                ListItem {
                    Text("Sources — combined / Claude only / Cursor only / Codex only / side-by-side.")
                }
                ListItem {
                    Text("JPY display — fetches FX once a day when enabled (no usage data on the wire).")
                }
                ListItem {
                    Text("Analytics — distribution builds only; off until you consent. Events go through AnalyticsService.")
                }
            }

            Text("Updates").docsSubheading()

            Text("""
            When a newer version exists, an Update button appears in the popover \
            footer. Detection polls GitHub Releases at launch and every 24 hours \
            after; the asset downloads only when you click the button.
            """)
            .foregroundStyle(.secondary)

            Text("Read more").docsSubheading()

            HStack(spacing: 16) {
                Link("Architecture", target: "\(sitePath)/docs/architecture")
                    .linkStyle(.underline(.heavy))
                Link("Privacy", target: "\(sitePath)/docs/privacy")
                    .linkStyle(.underline(.heavy))
                Link("Feature list on GitHub", target: "https://github.com/Tokfuel/Tokfuel#-features")
                    .linkStyle(.underline(.heavy))
            }
        }
        .frame(maxWidth: 720)
    }
}
