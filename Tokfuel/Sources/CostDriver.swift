import Foundation

/// 1 回の取得で得られる日別とモデル別の一貫したスナップショット。
struct CostSnapshot: Sendable, Equatable {
    var daily: [String: Double]
    var byModel: [String: Double]

    static let empty = CostSnapshot(daily: [:], byModel: [:])
}

/// Claude/retok に加えて合算する二次コスト源のための共通面。
protocol CostDriver: Sendable {
    var id: String { get }
    var displayName: String { get }

    /// ローカルにデータが存在するか（未インストール等なら false）。
    /// false のときは UI・合算のどちらにも一切影響を与えない（zero-setup の劣化と同じ形）。
    var isAvailable: Bool { get }

    /// [from, to] 区間（両端含む、"YYYY-MM-DD"）のコスト。
    func snapshot(from: String, to: String) async -> CostSnapshot
}

extension CostDriver {
    func dailyCosts(from: String, to: String) async -> [String: Double] {
        await snapshot(from: from, to: to).daily
    }
}
