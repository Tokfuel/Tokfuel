import Ignite

/// The fixed set of doc topics, one row per topic with both languages' titles and
/// slugs. This is the single source of truth for the sidebar — each `StaticPage`'s
/// own `path` still has to restate its slug (Ignite gives pages no way to read it
/// back from here), but the EN/JA title pairing itself no longer lives in two
/// independent arrays that could drift out of sync.
private struct DocTopic {
    let slug: String
    let titleEN: String
    let titleJA: String
}

private let docTopics: [DocTopic] = [
    DocTopic(slug: "usage", titleEN: "Usage guide", titleJA: "使い方ガイド"),
    DocTopic(slug: "architecture", titleEN: "Architecture", titleJA: "アーキテクチャ"),
    DocTopic(slug: "privacy", titleEN: "Privacy & network policy", titleJA: "プライバシー・通信ポリシー")
]

/// Shared layout for every documentation page (both languages). A top nav gets you
/// back to the landing page; a sidebar lists every doc page in both languages, since
/// pages don't know their own translated counterpart's path.
struct DocsLayout: Layout {
    var body: some Document {
        PlainDocument {
            Head()
            Body {
                NavigationBar(logo: "Tokfuel") {
                    Link("Home", target: "/")
                }
                .navigationBarStyle(.dark)
                .background(.black)

                Section {
                    HStack(alignment: .top, spacing: 48) {
                        VStack(spacing: 24) {
                            DocsNavGroup(
                                heading: "English",
                                items: docTopics.map { ($0.titleEN, "/docs/\($0.slug)") }
                            )

                            DocsNavGroup(
                                heading: "日本語",
                                items: docTopics.map { ($0.titleJA, "/ja/docs/\($0.slug)") }
                            )
                        }
                        .frame(maxWidth: 240)

                        VStack {
                            content
                        }
                        .frame(maxWidth: 720)
                    }
                }
                .padding(.vertical, 48)
                .horizontalAlignment(.center)
            }
        }
    }
}

/// One labeled group of links in the docs sidebar.
private struct DocsNavGroup: HTML {
    let heading: String
    let items: [(title: String, path: String)]

    var body: some HTML {
        VStack(spacing: 8) {
            Text(heading)
                .font(.small)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            List {
                for item in items {
                    ListItem {
                        Link(item.title, target: item.path)
                    }
                }
            }
            .listStyle(.plain)
        }
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
