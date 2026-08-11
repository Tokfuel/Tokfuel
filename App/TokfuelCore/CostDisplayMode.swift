import Foundation

/// ポップオーバーとメニューバーで、どのコストソースを金額に含めるか。
/// ソースは id で表す（Claude は `claudeSourceID`、二次ソースは `CostDriver.id`）。
public enum CostSourceMode: String, CaseIterable, Identifiable {
    /// Claude + 二次ソースを 1 つの合計にする（既定）。
    case combined
    case claudeOnly
    case cursorOnly
    case codexOnly
    /// ヒーローとメニューバーに Claude と Cursor を並べて出す。予算・ゲージの分母は合算。
    case sideBySide

    public var id: String { rawValue }

    /// Claude（retok）自身のソース id。`CostDriver.id` と同じ名前空間に置く。
    public static let claudeSourceID = "claude"
    /// `CursorCostDriver.id` / `CodexCostDriver.id` と同じ値。単独モードの判定に使う。
    public static let cursorSourceID = "cursor"
    public static let codexSourceID = "codex"

    public var label: String {
        switch self {
        case .combined: return "合算"
        case .claudeOnly: return "Claude のみ"
        case .cursorOnly: return "Cursor のみ"
        case .codexOnly: return "Codex のみ"
        case .sideBySide: return "並べて表示"
        }
    }

    /// 合算値（予算・ゲージ・グラフ・モデル別）にこのソースを含めるか。
    /// `sourceID` は `claudeSourceID` か `CostDriver.id`。単独モードは自分の id 以外を落とすので、
    /// 将来ドライバが増えても「◯◯ のみ」に他ソースが紛れ込まない。
    public func includes(sourceID: String) -> Bool {
        switch self {
        case .combined, .sideBySide: return true
        case .claudeOnly: return sourceID == Self.claudeSourceID
        case .cursorOnly: return sourceID == Self.cursorSourceID
        case .codexOnly: return sourceID == Self.codexSourceID
        }
    }

    /// 二次ソース 1 つだけを見るモードか。そのソースが取れていないときは表示額そのものが
    /// 不明になるので、メニューバーは 0 円ではなく「—」を出す。
    public var showsSingleSecondarySource: Bool {
        switch self {
        case .cursorOnly, .codexOnly: return true
        case .combined, .claudeOnly, .sideBySide: return false
        }
    }

    /// 「コストのソース」ピッカーに出す選択肢。Codex CLI が無いときに「Codex のみ」を選べると
    /// 常に $0 が並ぶだけなので、その場合は外す。
    public static func available(codexInstalled: Bool) -> [CostSourceMode] {
        allCases.filter { $0 != .codexOnly || codexInstalled }
    }

    /// 保存済みのモードが選べなくなっていたら既定（合算）へ落とす。
    public static func resolved(_ mode: CostSourceMode, codexInstalled: Bool) -> CostSourceMode {
        available(codexInstalled: codexInstalled).contains(mode) ? mode : .combined
    }
}

/// 推移チャートの描画形式。日別の棒（凸凹と内訳）か、期間の累積折れ線（ペース）か。
public enum CostChartStyle: String, CaseIterable, Identifiable {
    case daily
    case cumulative
    public var id: String { rawValue }
}

/// 「モデル別」セクションの並び方。
public enum CostModelBreakdownMode: String, CaseIterable, Identifiable {
    /// Claude と Cursor のモデルを 1 つの一覧にマージする。
    case combined
    /// Claude / Cursor をセクションに分けて出す。
    case separated

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .combined: return "まとめて"
        case .separated: return "ソース別に分ける"
        }
    }
}
