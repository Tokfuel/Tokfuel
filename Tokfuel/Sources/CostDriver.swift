import Foundation

/// Claude/retok に加えて合算するローカル二次コスト源のための共通面。
/// retok 固有の内訳（advice・top sessions・per-model・cache hit rate）はこのプロトコルの
/// 範囲外 — ここは「日別コストを足し合わせる」ためだけの最小限の面にとどめる。
/// 新しい二次ソースを足すときは、この protocol への準拠を 1 つ書き足すだけでよい。
protocol CostDriver: Sendable {
    var id: String { get }
    var displayName: String { get }

    /// ローカルにデータが存在するか（未インストール等なら false）。
    /// false のときは UI・合算のどちらにも一切影響を与えない（zero-setup の劣化と同じ形）。
    var isAvailable: Bool { get }

    /// [from, to] 区間（両端含む、"YYYY-MM-DD"）の日別コスト。データが無い日は含まない。
    /// 今日単体のコストは dailyCosts(from: today, to: today) で取れる。
    func dailyCosts(from: String, to: String) async -> [String: Double]
}
