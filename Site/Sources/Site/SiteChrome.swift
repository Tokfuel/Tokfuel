import Ignite

/// Shared sticky top nav.
/// Language / Theme are icon controls (SVG via site-chrome.js).
/// Search is an inline field in the bar; results drop down below.
struct SiteChrome: HTML {
    /// Active language for peer-language link. Home defaults to English.
    var language: DocsLanguage = .en
    /// Current docs topic when on a docs page; `nil` on Home.
    var topic: DocsTopic? = nil

    private var englishPath: String {
        if let topic { return topic.path(.en) }
        return "\(sitePath)/"
    }

    private var japanesePath: String {
        if let topic { return topic.path(.ja) }
        return "\(sitePath)/ja"
    }

    private var homePath: String {
        language == .ja ? "\(sitePath)/ja" : "\(sitePath)/"
    }

    private var peerLanguagePath: String {
        language == .ja ? englishPath : japanesePath
    }

    var body: some HTML {
        // `.width(.viewport)` must run while the value is still NavigationBar.
        // Avoid `.class` / `.attribute` on items — they erase `NavigationItem`.
        NavigationBar(logo: Link("Tokfuel", target: homePath)) {
            // Compact search field (Form is a NavigationItem; label is hidden in-nav).
            Form {
                TextField("Search", prompt: "Search…")
                    .type(.search)
                    .id("tf-search-input")
            }
            Link("Language", target: peerLanguagePath)
            Link("Theme", target: "#")
            Link(target: "https://github.com/Tokfuel/Tokfuel") {
                Span("GitHub")
                    .class("tf-github-label")
                Span {
                    Span {
                        Span("★ ")
                        Span("—")
                            .class("tf-star-count")
                    }
                    .class("tf-github-fact")
                    Span {
                        Span("⑂ ")
                        Span("—")
                            .class("tf-fork-count")
                    }
                    .class("tf-github-fact")
                }
                .class("tf-github-facts")
            }
        }
        .width(.viewport)
        .navigationBarStyle(.dark)
        .background(Brand.nav)
        .class("tf-chrome sticky-top")

        // Results panel for the nav search field (shown/hidden by site-chrome.js).
        Section {
            Text("Type to search docs.")
                .font(.small)
                .foregroundStyle(.secondary)
                .class("tf-search-empty")
        }
        .id("tf-search-results")
        .class("tf-search-panel")
        .attribute("hidden", "hidden")

        Script(file: "\(sitePath)/js/bootstrap.bundle.min.js")
        Script(file: "\(sitePath)/js/ignite-core.js")
        Script(file: "\(sitePath)/js/site-chrome.js")
    }
}
