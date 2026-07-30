import Ignite

struct Home: StaticPage {
    var path = "/"
    var title = "Tokfuel — See what AI coding costs you"
    var description = "See what AI coding costs you, from the menu bar. A tiny, local-only SwiftUI app for macOS."

    var releasesURL = "https://github.com/Tokfuel/Tokfuel/releases/latest"
    var sourceURL = "https://github.com/Tokfuel/Tokfuel"

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

                Link("Download for macOS", target: releasesURL)
                    .linkStyle(.button)
                    .role(.primary)
                    .padding(.horizontal, 8)

                Text("macOS 14 or later · Free and open source")
                    .font(.small)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 96)
        }
        .background(.black)
        .foregroundStyle(.white)

        Section {
            Image("images/screenshot.png", description: "Tokfuel's menu-bar popover showing cost, budgets, and per-model breakdown")
                .resizable()
                .cornerRadius(16)
                .frame(maxWidth: 720)
        }
        .padding(.vertical, 64)

        Section {
            VStack(spacing: 16) {
                Text("How it works")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("""
                Tokfuel reads the transcripts Claude Code already writes under \
                ~/.claude/projects/ — nothing to configure, nothing installed \
                on top of what you already have. Everything stays on your Mac; \
                the only network call is an opt-in daily exchange-rate fetch.
                """)
                .frame(maxWidth: 640)
                .foregroundStyle(.secondary)

                Link("View source and full details on GitHub", target: sourceURL)
                    .linkStyle(.underline(.heavy))
            }
            .padding(.vertical, 64)
        }
    }
}
