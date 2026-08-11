import Ignite

/// Line-coverage snapshot from `swift test --enable-code-coverage`
/// (llvm-cov export over App/ sources). Refresh when regenerating the site
/// after a meaningful test or product change.
enum CoverageSnapshot {
    static let asOf = "2026-08-08"
    static let unitTests = 367
    static let suites = 63
    static let appLinesCovered = 2821
    static let appLinesTotal = 7800

    static var appLinePercent: Double {
        100.0 * Double(appLinesCovered) / Double(appLinesTotal)
    }

    /// SPM product modules under App/, highest coverage first.
    /// The Tokfuel executable target is mostly SwiftUI glue — listed last.
    static let modules: [CoverageModule] = [
        CoverageModule(name: "TokfuelCursor", covered: 695, total: 753),
        CoverageModule(name: "TokfuelCore", covered: 619, total: 794),
        CoverageModule(name: "TokfuelSettings", covered: 168, total: 228),
        CoverageModule(name: "TokfuelBudget", covered: 91, total: 146),
        CoverageModule(name: "TokfuelStore", covered: 448, total: 910),
        CoverageModule(name: "TokfuelClaude", covered: 132, total: 284),
        CoverageModule(name: "TokfuelCodex", covered: 15, total: 35),
        CoverageModule(name: "TokfuelAnalytics", covered: 17, total: 59),
        CoverageModule(name: "TokfuelUI", covered: 602, total: 4021),
        CoverageModule(name: "Tokfuel (app)", covered: 34, total: 570),
    ]
}

struct CoverageModule {
    let name: String
    let covered: Int
    let total: Int

    var percent: Double {
        guard total > 0 else { return 0 }
        return 100.0 * Double(covered) / Double(total)
    }

    var percentLabel: String {
        String(format: "%.0f%%", percent)
    }
}

/// Shared coverage chart for EN / JA testing pages.
struct CoverageChart: HTML {
    var language: DocsLanguage

    private var isJA: Bool { language == .ja }

    var body: some HTML {
        Section {
            Text(isJA ? "カバレッジ（行）" : "Line coverage")
                .docsSubheading()

            Text(isJA
                 ? "swift test --enable-code-coverage のスナップショット（\(CoverageSnapshot.asOf)）。App/ 配下のみ。依存の checkouts は含みません。"
                 : "Snapshot from swift test --enable-code-coverage (\(CoverageSnapshot.asOf)). App/ sources only — dependency checkouts excluded.")
                .font(.small)
                .foregroundStyle(.secondary)

            Section {
                Text(isJA
                     ? "ユニットテスト \(CoverageSnapshot.unitTests) 件 / \(CoverageSnapshot.suites) スイート"
                     : "\(CoverageSnapshot.unitTests) unit tests / \(CoverageSnapshot.suites) suites")
                    .fontWeight(.semibold)
                Text(isJA
                     ? "App 合計 \(CoverageSnapshot.appLinesCovered) / \(CoverageSnapshot.appLinesTotal) 行（\(String(format: "%.1f", CoverageSnapshot.appLinePercent))%）"
                     : "App total \(CoverageSnapshot.appLinesCovered) / \(CoverageSnapshot.appLinesTotal) lines (\(String(format: "%.1f", CoverageSnapshot.appLinePercent))%)")
                    .font(.small)
                    .foregroundStyle(.secondary)
            }
            .class("tf-cov-summary")

            Section {
                for module in CoverageSnapshot.modules {
                    Section {
                        HStack(alignment: .center, spacing: 12) {
                            Text(module.name)
                                .font(.small)
                                .fontWeight(.semibold)
                                .class("tf-cov-name")
                            Spacer()
                            Text("\(module.percentLabel)  \(module.covered)/\(module.total)")
                                .font(.small)
                                .foregroundStyle(.secondary)
                                .class("tf-cov-meta")
                        }
                        Section {
                            Section {}
                                .class("tf-cov-fill")
                                .attribute("style", "width: \(Int(module.percent.rounded()))%")
                        }
                        .class("tf-cov-track")
                    }
                    .class("tf-cov-row")
                }
            }
            .class("tf-cov-chart")

            Text(isJA
                 ? "TokfuelUI と実行ファイル（Tokfuel）は SwiftUI の見た目寄りなので行カバレッジは低く出ます。見た目は ui-preview、ロジックは UnitTests で担保します。"
                 : "TokfuelUI and the Tokfuel executable skew toward SwiftUI surfaces, so line coverage reads low there. Looks go through ui-preview; headless logic stays in UnitTests.")
                .font(.small)
                .foregroundStyle(.secondary)
        }
        .class("tf-cov")
    }
}
