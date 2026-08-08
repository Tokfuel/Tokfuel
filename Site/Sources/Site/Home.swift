import Ignite

struct Home: StaticPage {
    var path = "/"
    var title = "Tokfuel — See what AI coding costs you"
    var description = "See what AI coding costs you, from the menu bar. A tiny, local-only SwiftUI app for macOS."

    var downloadURL = "https://github.com/Tokfuel/Tokfuel/releases/latest/download/Tokfuel-latest.dmg"
    var sourceURL = "https://github.com/Tokfuel/Tokfuel"
    var ownerURL = "https://github.com/Tokfuel"

    var body: some HTML {
        Section {
            VStack(spacing: 24) {
                Image("images/app-icon.png", description: "Tokfuel app icon")
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(28)

                Text("Tokfuel")
                    .font(.title1)
                    .fontWeight(.bold)

                Text("See what AI coding costs you — from the menu bar.")
                    .font(.lead)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 560)

                Link("Download for macOS", target: downloadURL)
                    .linkStyle(.button)
                    .role(.primary)
                    .padding(.horizontal, 8)

                Text("macOS 14 or later · Free and open source")
                    .font(.small)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 96)
            .padding(.horizontal, 32)
            .horizontalAlignment(.leading)
        }
        .background(Brand.heroGradient)
        .foregroundStyle(.white)
        .horizontalAlignment(.leading)

        Section {
            Image("images/screenshot.png", description: "Tokfuel's menu-bar popover showing cost, budgets, and per-model breakdown")
                .resizable()
                .cornerRadius(16)
                .frame(maxWidth: 720)
        }
        .padding(.vertical, 64)
        .padding(.horizontal, 32)
        .horizontalAlignment(.leading)

        Section {
            VStack(spacing: 16) {
                Text("How it works")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("""
                Tokfuel reads the transcripts Claude Code already writes under \
                ~/.claude/projects/ — nothing to configure, nothing installed \
                on top of what you already have. Usage data stays on your Mac. \
                Disclosed network requests are limited to an opt-in exchange-rate \
                fetch and, when Cursor is present, its published pricing and \
                signed-in dashboard usage APIs. Prompts are never sent.
                """)
                .frame(maxWidth: 640)
                .foregroundStyle(.secondary)
                .horizontalAlignment(.leading)

                Link("View source and full details on GitHub", target: sourceURL)
                    .linkStyle(.underline(.heavy))

                HStack(spacing: 16) {
                    Link("Read the docs", target: "\(sitePath)/docs/usage")
                        .linkStyle(.underline(.heavy))
                    Link("ドキュメント（日本語）", target: "\(sitePath)/ja/docs/usage")
                        .linkStyle(.underline(.heavy))
                }
            }
            .padding(.vertical, 64)
            .padding(.horizontal, 32)
            .horizontalAlignment(.leading)
        }
        .horizontalAlignment(.leading)

        Section {
            Text {
                "MIT License · © "
                Link("Tokfuel", target: ownerURL)
                    .linkStyle(.underline(.heavy))
            }
            .font(.small)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 32)
        .horizontalAlignment(.leading)
    }
}
