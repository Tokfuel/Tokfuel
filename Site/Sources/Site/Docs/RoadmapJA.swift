import Ignite

struct RoadmapJA: StaticPage {
    var path = "/ja/docs/roadmap"
    var title = "ロードマップ — Tokfuel"
    var description = "Tokfuel が次に取り組む項目。GitHub Issues のロードマップのスナップショットです。"
    var layout: DocsLayout { DocsLayout(page: .roadmap, language: .ja) }

    var body: some HTML {
        VStack(alignment: .leading, spacing: 24) {
            Text("ロードマップ").docsTitle()

            Text("""
            機能と修正は GitHub Issue（TF-NNNN）として管理しています。作業用のボードは \
            GitHub Projects の Tokfuel Roadmap です。このページは「進行中」と「これから」の \
            読みやすいスナップショットであり、ライブ同期ではありません。
            """)
            .foregroundStyle(.secondary)

            Text("スナップショット日: \(RoadmapSnapshot.asOf)。ボードが進んだらこのページを更新してください。")
                .font(.small)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Link("Open Issues", target: RoadmapSnapshot.issuesURL)
                    .linkStyle(.underline(.heavy))
                Link("GitHub Project", target: RoadmapSnapshot.projectURL)
                    .linkStyle(.underline(.heavy))
            }

            Text("進め方").docsSubheading()

            Text("""
            新機能は Proposal、バグは Bug report のテンプレートを使います。ラベルは種別 \
            （enhancement / bugs / docs / chore）と、当てはまるなら領域（product / web / ci）を \
                付けます。次に着手する項目はオープンな Issue から選び、ボード上の状態は \
                In progress、Todo、Done です。
            """)
            .foregroundStyle(.secondary)

            RoadmapLists(language: .ja)

            Text("関連").docsSubheading()

            HStack(spacing: 16) {
                Link("使い方ガイド", target: "\(sitePath)/ja/docs/usage")
                    .linkStyle(.underline(.heavy))
                Link("アーキテクチャ", target: "\(sitePath)/ja/docs/architecture")
                    .linkStyle(.underline(.heavy))
                Link("ADR 一覧", target: "\(sitePath)/ja/docs/adr")
                    .linkStyle(.underline(.heavy))
            }
        }
        .frame(maxWidth: 720)
    }
}
