import Foundation

/// ポップオーバーとメニューバーで、Claude / Cursor のどちらを金額に含めるか。
enum CostSourceMode: String, CaseIterable, Identifiable {
    /// Claude + Cursor を 1 つの合計にする（既定）。
    case combined
    case claudeOnly
    case cursorOnly
    /// ヒーローとメニューバーに Claude と Cursor を並べて出す。予算・ゲージの分母は合算。
    case sideBySide

    var id: String { rawValue }

    var label: String {
        switch self {
        case .combined: return "合算"
        case .claudeOnly: return "Claude のみ"
        case .cursorOnly: return "Cursor のみ"
        case .sideBySide: return "並べて表示"
        }
    }

    /// 合算値（予算・ゲージ）に Claude を含めるか。
    var includesClaude: Bool {
        switch self {
        case .combined, .sideBySide, .claudeOnly: return true
        case .cursorOnly: return false
        }
    }

    /// 合算値（予算・ゲージ）に Cursor を含めるか。
    var includesCursor: Bool {
        switch self {
        case .combined, .sideBySide, .cursorOnly: return true
        case .claudeOnly: return false
        }
    }
}

/// 推移チャートの描画形式。日別の棒（凸凹と内訳）か、期間の累積折れ線（ペース）か。
enum CostChartStyle: String, CaseIterable, Identifiable {
    case daily
    case cumulative
    var id: String { rawValue }
}

/// 「モデル別」セクションの並び方。
enum CostModelBreakdownMode: String, CaseIterable, Identifiable {
    /// Claude と Cursor のモデルを 1 つの一覧にマージする。
    case combined
    /// Claude / Cursor をセクションに分けて出す。
    case separated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .combined: return "まとめて"
        case .separated: return "ソース別に分ける"
        }
    }
}
