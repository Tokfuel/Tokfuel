import Foundation

/// 1 セッション分の累積値（retok の new_session() 相当）。
/// 走査ループから多箇所で書き換えるため、辞書内でも参照で更新できる class にしている。
/// detached タスク内に閉じて使うので Sendable にはしない。
/// retok がターミナル描画専用に持つフィールド（first/last ts・sidechain 内訳）は、
/// アプリの JSON レポートに現れないため移植していない。
final class RetokSession {
    var provider: String?       // "claude" / "codex"
    var project: String?
    var prompts = 0
    var interruptions = 0
    var requests = 0
    var input = 0
    var output = 0
    var cacheRead = 0
    var cacheWrite = 0
    var cost = 0.0
    var maxContext = 0
    /// TTL 超過ギャップ直後のキャッシュ書込（再キャッシュと推定した分）。
    var expiredCacheWrite = 0
    var expiredCacheCost = 0.0
    var tools: [String: Int] = [:]           // メインスレッドの tool_use 回数
    var bashCommands: [String: Int] = [:]    // 同一コマンド再試行の検出用
    var models: Set<String> = []
    var prevReqTS: Date?
}

/// Claude / Codex 両スキャナが共有する走査状態。
/// retok は 1 つの seen_msg_ids セットに文字列 / タプルを混在させるが、型が違い衝突しないので
/// Swift では 3 つのセットに分ける（等価）。
final class RetokScanState {
    struct ModelAccumulator {
        var cost = 0.0
        var input = 0
        var output = 0
        var cacheRead = 0
        var cacheWrite = 0
        var requests = 0
    }

    struct DayAccumulator {
        var cost = 0.0
        var output = 0
    }

    var sessions: [String: RetokSession] = [:]
    /// API レスポンス ID（複数行・ミラーされたファイル間の二重計上防止。走査全体でグローバル）。
    var seenMessageIDs: Set<String> = []
    /// tool_use ブロック（message.id + block.id）。
    var seenToolBlocks: Set<String> = []
    /// Codex の重複リプレイ検出キー（sessionId + 生タイムスタンプ + 累積トークン）。
    var seenCodexKeys: Set<String> = []
    var daily: [String: DayAccumulator] = [:]
    var perModel: [String: ModelAccumulator] = [:]
    var filesScanned = 0

    /// defaultdict 相当: 無ければ作って返す。
    func session(for id: String) -> RetokSession {
        if let s = sessions[id] { return s }
        let s = RetokSession()
        sessions[id] = s
        return s
    }

    func addDaily(day: String, cost: Double, output: Int) {
        var d = daily[day] ?? DayAccumulator()
        d.cost += cost
        d.output += output
        daily[day] = d
    }

    func addModel(_ model: String, cost: Double, input: Int, output: Int,
                  cacheRead: Int, cacheWrite: Int) {
        var m = perModel[model] ?? ModelAccumulator()
        m.cost += cost
        m.input += input
        m.output += output
        m.cacheRead += cacheRead
        m.cacheWrite += cacheWrite
        m.requests += 1
        perModel[model] = m
    }
}
