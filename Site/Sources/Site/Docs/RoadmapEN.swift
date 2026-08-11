import Ignite

struct RoadmapEN: StaticPage {
    var path = "/docs/roadmap"
    var title = "Roadmap — Tokfuel"
    var description = "What Tokfuel is working on next. Snapshot of the public GitHub Issues roadmap."
    var layout: DocsLayout { DocsLayout(page: .roadmap, language: .en) }

    var body: some HTML {
        VStack(alignment: .leading, spacing: 24) {
            Text("Roadmap").docsTitle()

            Text("""
            Features and fixes land as GitHub Issues (TF-NNNN). The working board is \
            Tokfuel Roadmap on GitHub Projects. This page is a readable snapshot of \
            In progress and Todo — not a live sync.
            """)
            .foregroundStyle(.secondary)

            Text("Snapshot date: \(RoadmapSnapshot.asOf). When the board moves, regenerate this page.")
                .font(.small)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Link("Open Issues", target: RoadmapSnapshot.issuesURL)
                    .linkStyle(.underline(.heavy))
                Link("GitHub Project", target: RoadmapSnapshot.projectURL)
                    .linkStyle(.underline(.heavy))
            }

            Text("How work is chosen").docsSubheading()

            Text("""
            New ideas use the Proposal template; bugs use Bug report. Labels mark \
            kind (enhancement, bugs, docs, chore) and area (product, web, ci) when \
            they apply. Agents and contributors pick the next item from open Issues — \
            the board status is In progress, Todo, or Done.
            """)
            .foregroundStyle(.secondary)

            RoadmapLists(language: .en)

            Text("Related").docsSubheading()

            HStack(spacing: 16) {
                Link("Usage guide", target: "\(sitePath)/docs/usage")
                    .linkStyle(.underline(.heavy))
                Link("Architecture", target: "\(sitePath)/docs/architecture")
                    .linkStyle(.underline(.heavy))
                Link("ADR index", target: "\(sitePath)/docs/adr")
                    .linkStyle(.underline(.heavy))
            }
        }
        .frame(maxWidth: 720)
    }
}
