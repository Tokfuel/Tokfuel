import Ignite

/// Shared layout for documentation pages. Full-bleed black nav, system type,
/// left-aligned article — see `Site/DESIGN.ja.md`.
struct DocsLayout: Layout {
    var page: DocsTopic
    var language: DocsLanguage

    var body: some Document {
        PlainDocument {
            Head {
                // MetaLink root-absolute paths already get `sitePath` via Ignite's assetPath.
                MetaLink(href: "/css/tokfuel.css", rel: .stylesheet)
            }
            Body {
                SiteChrome(language: language, topic: page)

                if language == .ja {
                    Script(file: "\(sitePath)/js/budoux-ja.min.js")
                    Script(file: "\(sitePath)/js/budoux-apply.js")
                    Script(code: "(function(){var s=document.createElement('style');s.textContent='[data-budoux-root=\"true\"]{word-break:keep-all;overflow-wrap:anywhere;}';document.head.appendChild(s);}());")
                }

                Section {
                    VStack(alignment: .leading, spacing: 28) {
                        HStack(alignment: .top, spacing: 48) {
                            DocsSidebar(current: page, language: language)
                                .frame(width: 220)
                                .class("tf-docs-sidebar")

                            VStack(alignment: .leading, spacing: 0) {
                                content
                            }
                            .frame(maxWidth: 720)
                            .horizontalAlignment(.leading)
                            .attribute("data-budoux-root", language == .ja ? "true" : "false")
                        }
                    }
                    .class("tf-docs-shell")
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 32)
                .horizontalAlignment(.leading)
            }
            .ignorePageGutters()
        }
    }
}

/// The doc language a page renders in.
enum DocsLanguage {
    case en, ja
}

/// Fixed doc topics — single source of truth for both sidebars.
enum DocsTopic: CaseIterable {
    case usage, architecture, adr, testing, privacy, roadmap

    var slug: String {
        switch self {
        case .usage: "usage"
        case .architecture: "architecture"
        case .adr: "adr"
        case .testing: "testing"
        case .privacy: "privacy"
        case .roadmap: "roadmap"
        }
    }

    var titleEN: String {
        switch self {
        case .usage: "Usage guide"
        case .architecture: "Architecture"
        case .adr: "ADR index"
        case .testing: "Tests & verification"
        case .privacy: "Privacy & network policy"
        case .roadmap: "Roadmap"
        }
    }

    var titleJA: String {
        switch self {
        case .usage: "使い方ガイド"
        case .architecture: "アーキテクチャ"
        case .adr: "ADR 一覧"
        case .testing: "テストと検証"
        case .privacy: "プライバシー・通信ポリシー"
        case .roadmap: "ロードマップ"
        }
    }

    func title(_ language: DocsLanguage) -> String {
        language == .en ? titleEN : titleJA
    }

    func path(_ language: DocsLanguage) -> String {
        language == .en ? "\(sitePath)/docs/\(slug)" : "\(sitePath)/ja/docs/\(slug)"
    }
}

private struct DocsSidebar: HTML {
    let current: DocsTopic
    let language: DocsLanguage

    var body: some HTML {
        // Always render links (never swap to bare Text). Swapping <p> ↔ <a>
        // changes box metrics and makes the TOC jump when you tap another page.
        List {
            for topic in DocsTopic.allCases {
                ListItem {
                    Link(topic.title(language), target: topic.path(language))
                        .class(topic == current ? "is-current" : "is-nav")
                }
            }
        }
        .listStyle(.plain)
        .class("tf-docs-nav")
    }
}

extension Text {
    func docsTitle() -> some HTML {
        font(.title2).fontWeight(.bold)
    }

    func docsSubheading() -> some HTML {
        font(.title4).fontWeight(.semibold)
    }
}
