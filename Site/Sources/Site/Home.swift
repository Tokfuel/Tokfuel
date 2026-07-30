import Ignite

struct Home: StaticPage {
    var path = "/"
    var title = "Tokfuel — See what AI coding costs you"
    var description = "See what AI coding costs you, from the menu bar. A tiny, local-only SwiftUI app for macOS."

    var downloadURL = "https://github.com/Tokfuel/Tokfuel/releases/latest/download/Tokfuel-latest.dmg"
    var sourceURL = "https://github.com/Tokfuel/Tokfuel"
    var authorURL = "https://github.com/akidon0000"

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
            .horizontalAlignment(.center)
        }
        .background(.black)
        .foregroundStyle(.white)
        .horizontalAlignment(.center)

        Section {
            Image("images/screenshot.png", description: "Tokfuel's menu-bar popover showing cost, budgets, and per-model breakdown")
                .resizable()
                .cornerRadius(16)
                .frame(maxWidth: 720)
                .class("d-block", "mx-auto")
        }
        .padding(.vertical, 64)
        .horizontalAlignment(.center)

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
                .horizontalAlignment(.center)

                Link("View source and full details on GitHub", target: sourceURL)
                    .linkStyle(.underline(.heavy))
            }
            .padding(.vertical, 64)
            .horizontalAlignment(.center)
        }
        .horizontalAlignment(.center)

        Section {
            Text {
                "MIT License · © "
                Link("Dan Akiyama (@akidon0000)", target: authorURL)
                    .linkStyle(.underline(.heavy))
            }
            .font(.small)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 32)
        .horizontalAlignment(.center)
    }
}
