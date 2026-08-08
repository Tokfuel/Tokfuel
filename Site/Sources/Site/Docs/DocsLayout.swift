import Ignite

/// The doc language a page renders in. Each `DocsLayout` is told both this and its
/// `DocsTopic`, since Ignite pages are independent static structs with no way to
/// discover their own translated counterpart on their own.
enum DocsLanguage {
    case en, ja
}

/// The fixed set of doc topics, one row per topic with both languages' titles and a
/// shared slug. Single source of truth for both the English and Japanese sidebars,
/// so adding a topic can't leave one language's nav out of sync with the other.
enum DocsTopic: CaseIterable {
    case usage, architecture, privacy

    var slug: String {
        switch self {
        case .usage: "usage"
        case .architecture: "architecture"
        case .privacy: "privacy"
        }
    }

    var titleEN: String {
        switch self {
        case .usage: "Usage guide"
        case .architecture: "Architecture"
        case .privacy: "Privacy & network policy"
        }
    }

    var titleJA: String {
        switch self {
        case .usage: "使い方ガイド"
        case .architecture: "アーキテクチャ"
        case .privacy: "プライバシー・通信ポリシー"
        }
    }

    func title(_ language: DocsLanguage) -> String {
        language == .en ? titleEN : titleJA
    }

    func path(_ language: DocsLanguage) -> String {
        language == .en ? "\(sitePath)/docs/\(slug)" : "\(sitePath)/ja/docs/\(slug)"
    }
}

/// Shared layout for every documentation page. Styled after Bajutsu's docs site: an
/// indigo top bar with a light/dark toggle, a compact "English · 日本語" language
/// switcher above the content, and a sidebar listing only the current language's
/// pages (the current one shown as plain text, not a link) rather than both
/// languages at once.
struct DocsLayout: Layout {
    var page: DocsTopic
    var language: DocsLanguage

    var body: some Document {
        PlainDocument {
            Head()
            Body {
                // NavigationBar's `logo:` parameter always links to a hardcoded "/",
                // which is wrong once the site is served from a GitHub Pages project
                // subpath (see `sitePath`) — so the brand name is a plain nav item
                // instead, where the target is ours to control.
                NavigationBar(logo: nil) {
                    Link("Tokfuel", target: "\(sitePath)/")
                }
                .navigationBarStyle(.dark)
                .background(Brand.indigo)

                // Ignite's own `Script(file: "/js/...")` calls (added unconditionally by
                // `Body`) are always root-absolute and never get `sitePath` prepended, so
                // on this project-subpage deployment they 404 and `igniteSwitchTheme` /
                // Bootstrap's collapse JS silently don't exist. These correctly-prefixed
                // duplicates make the theme toggle and the mobile nav collapse work; the
                // extra failed request underneath is harmless.
                Script(file: "\(sitePath)/js/bootstrap.bundle.min.js")
                Script(file: "\(sitePath)/js/ignite-core.js")

                Section {
                    HStack(alignment: .center, spacing: 12) {
                        Spacer()
                        Link("☀︎", target: "#")
                            .onClick { SwitchTheme(TokfuelTheme(colorScheme: .light)) }
                        Link("☾", target: "#")
                            .onClick { SwitchTheme(TokfuelTheme(colorScheme: .dark)) }
                    }
                }
                .background(Brand.indigo)
                .foregroundStyle(.white)
                .padding(.bottom, 8)

                Section {
                    Text {
                        Link("English", target: page.path(.en))
                            .fontWeight(language == .en ? .bold : .regular)
                        " · "
                        Link("日本語", target: page.path(.ja))
                            .fontWeight(language == .ja ? .bold : .regular)
                    }
                    .font(.small)
                    .padding(.top, 24)

                    HStack(alignment: .top, spacing: 48) {
                        DocsSidebar(current: page, language: language)
                            .frame(maxWidth: 220)

                        VStack {
                            content
                        }
                        .frame(maxWidth: 720)
                    }
                }
                .padding(.vertical, 24)
                .horizontalAlignment(.center)
            }
        }
    }
}

/// The sidebar for one language: every doc topic, with the current page shown as
/// plain (non-clickable) text instead of a link.
private struct DocsSidebar: HTML {
    let current: DocsTopic
    let language: DocsLanguage

    var body: some HTML {
        List {
            for topic in DocsTopic.allCases {
                ListItem {
                    if topic == current {
                        Text(topic.title(language)).fontWeight(.bold)
                    } else {
                        Link(topic.title(language), target: topic.path(language))
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

/// Shared heading styles so every doc page's title and subheadings render identically
/// without repeating the same two modifiers at every call site.
extension Text {
    func docsTitle() -> some HTML {
        font(.title2).fontWeight(.bold)
    }

    func docsSubheading() -> some HTML {
        font(.title4).fontWeight(.bold)
    }
}
