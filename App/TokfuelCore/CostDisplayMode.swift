import Foundation

public enum CostSourceMode: String, CaseIterable, Identifiable {
    case combined
    case claudeOnly
    case cursorOnly
    case codexOnly
    case sideBySide

    public var id: String { rawValue }

    public static let claudeSourceID = "claude"
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

    /// `sourceID` は `claudeSourceID` か `CostDriver.id`。単独モードは自分の id 以外を落とすので、
    public func includes(sourceID: String) -> Bool {
        switch self {
        case .combined, .sideBySide: return true
        case .claudeOnly: return sourceID == Self.claudeSourceID
        case .cursorOnly: return sourceID == Self.cursorSourceID
        case .codexOnly: return sourceID == Self.codexSourceID
        }
    }

    /// 不明になるので、メニューバーは 0 円ではなく「—」を出す。
    public var showsSingleSecondarySource: Bool {
        switch self {
        case .cursorOnly, .codexOnly: return true
        case .combined, .claudeOnly, .sideBySide: return false
        }
    }

    /// 常に $0 が並ぶだけなので、その場合は外す。
    public static func available(codexInstalled: Bool) -> [CostSourceMode] {
        allCases.filter { $0 != .codexOnly || codexInstalled }
    }

    public static func resolved(_ mode: CostSourceMode, codexInstalled: Bool) -> CostSourceMode {
        available(codexInstalled: codexInstalled).contains(mode) ? mode : .combined
    }
}

public enum CostChartStyle: String, CaseIterable, Identifiable {
    case daily
    case cumulative
    public var id: String { rawValue }
}

public enum CostModelBreakdownMode: String, CaseIterable, Identifiable {
    case combined
    case separated

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .combined: return "まとめて"
        case .separated: return "ソース別に分ける"
        }
    }
}
