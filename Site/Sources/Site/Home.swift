import Ignite

struct Home: StaticPage {
    var path = "/"
    var title = "Tokfuel — See what AI coding costs you"
    var description = "See what AI coding costs you, from the menu bar. A tiny, local-only SwiftUI app for macOS."

    var downloadURL = "https://github.com/Tokfuel/Tokfuel/releases/latest/download/Tokfuel-latest.dmg"
    var sourceURL = "https://github.com/Tokfuel/Tokfuel"
    var ownerURL = "https://github.com/Tokfuel"

    var body: some HTML {
        SiteChrome(language: .en, topic: nil)

        Section {
            VStack(alignment: .leading, spacing: 28) {
                Image("/images/app-icon.png", description: "Tokfuel app icon")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .cornerRadius(26)

                Text("Tokfuel")
                    .font(.title1)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("See what AI coding costs you — from the menu bar.")
                    .font(.lead)
                    .foregroundStyle(Color(hex: "#A1A1A6"))
                    .frame(maxWidth: 560)

                Link("Download for macOS", target: downloadURL)
                    .linkStyle(.button)
                    .role(.primary)

                Text("macOS 14 or later. Free and open source.")
                    .font(.small)
                    .foregroundStyle(Color(hex: "#86868B"))
            }
            .padding(.vertical, 96)
            .padding(.horizontal, 32)
            .frame(maxWidth: 980)
        }
        .class("tf-hero")
        .foregroundStyle(.white)
        .horizontalAlignment(.leading)

        Section {
            Image("/images/screenshot.png", description: "Tokfuel's menu-bar popover showing cost, budgets, and per-model breakdown")
                .resizable()
                .cornerRadius(12)
                .frame(maxWidth: 720)
        }
        .padding(.vertical, 72)
        .padding(.horizontal, 32)
        .horizontalAlignment(.leading)
        .class("tf-section-muted")

        Section {
            VStack(alignment: .leading, spacing: 20) {
                Text("How it works")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("""
                Tokfuel reads what Claude Code, Codex CLI, and Cursor already \
                leave on your Mac (~/.claude/projects/, ~/.codex/sessions/, and \
                Cursor's local data) — no hooks, no setup. Each source stays \
                labeled; nothing is mixed into a silent Claude total. Usage data \
                and prompts never leave your Mac. The few network calls \
                (optional FX rate, Cursor pricing / dashboard when present, \
                update checks, and — in distribution builds — Crashlytics plus \
                opt-in Analytics) are listed on the privacy page.
                """)
                .frame(maxWidth: 640)
                .foregroundStyle(.secondary)

                Link("View source and full details on GitHub", target: sourceURL)
                    .linkStyle(.underline(.heavy))

                HStack(alignment: .center, spacing: 20) {
                    Link("Read the docs", target: "\(sitePath)/docs/usage")
                        .linkStyle(.underline(.heavy))
                    Link("Roadmap", target: "\(sitePath)/docs/roadmap")
                        .linkStyle(.underline(.heavy))
                    Link("Privacy", target: "\(sitePath)/docs/privacy")
                        .linkStyle(.underline(.heavy))
                    Link("ADR index", target: "\(sitePath)/docs/adr")
                        .linkStyle(.underline(.heavy))
                    Link("Tests", target: "\(sitePath)/docs/testing")
                        .linkStyle(.underline(.heavy))
                }
            }
            .padding(.vertical, 72)
            .padding(.horizontal, 32)
            .frame(maxWidth: 980)
        }
        .horizontalAlignment(.leading)

        Section {
            Text {
                "MIT License. © "
                Link("Tokfuel", target: ownerURL)
                    .linkStyle(.underline(.heavy))
            }
            .font(.small)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 32)
        .horizontalAlignment(.leading)
        .class("tf-section-muted")
    }
}
