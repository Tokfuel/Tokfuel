import Foundation

/// 集計値から改善アドバイスを組み立てる（retok.py build_advice() の移植）。
/// 7 つの規則の閾値・追加順は retok と同一。params は文言に埋め込む整形済み文字列。
enum RetokAdvice {
    struct Item {
        let severity: String   // "high" / "medium" / "low" / "info"
        let key: String        // "adv_cache_hit" など（_title / _detail を後置して文言を引く）
        let params: [String: String]
    }

    /// これを超えるコンテキストは /clear・/compact を提案する閾値（トークン）。
    static let largeContextThreshold = 120_000
    static let searchTools: Set<String> = ["Read", "Grep", "Glob", "Explore"]

    struct Totals {
        var cost = 0.0
        var input = 0
        var output = 0
        var cacheRead = 0
        var cacheWrite = 0
        var prompts = 0
        var requests = 0
    }

    static func build(sessions: [RetokSession], totals: Totals)
        -> (advice: [Item], hitRate: Double) {
        var advice: [Item] = []

        // 1. キャッシュヒット率
        let denom = totals.input + totals.cacheRead + totals.cacheWrite
        let hit = denom > 0 ? Double(totals.cacheRead) / Double(denom) : 0.0
        if hit < 0.75, denom > 1_000_000 {
            advice.append(Item(severity: "high", key: "adv_cache_hit",
                               params: ["rate": percentString(hit)]))
        }

        // 2. キャッシュ TTL 失効の再キャッシュコスト
        let expCost = sessions.reduce(0.0) { $0 + $1.expiredCacheCost }
        let expTokens = sessions.reduce(0) { $0 + $1.expiredCacheWrite }
        if expCost > 1.0 {
            advice.append(Item(severity: "high", key: "adv_ttl",
                               params: ["mtok": String(format: "%.1f", Double(expTokens) / 1e6),
                                        "cost": String(format: "%.2f", expCost)]))
        }

        // 3. 肥大化したセッションコンテキスト
        let fat = sessions.filter {
            $0.maxContext > Self.largeContextThreshold && $0.prompts >= 3
        }
        if !fat.isEmpty {
            let worst = fat.map(\.maxContext).max() ?? 0
            advice.append(Item(severity: "high", key: "adv_fat_ctx",
                               params: ["count": "\(fat.count)",
                                        "limit": "\(Self.largeContextThreshold / 1000)",
                                        "max": "\(worst / 1000)"]))
        }

        // 4. 委譲: メインスレッドで探索が多いのにサブエージェント利用が少ない（Claude のみ）
        let claudeSessions = sessions.filter { $0.provider == "claude" }
        let mainToolTotal = claudeSessions.reduce(0) { $0 + $1.tools.values.reduce(0, +) }
        let searchCalls = claudeSessions.reduce(0) { acc, s in
            acc + s.tools.filter { Self.searchTools.contains($0.key) }
                .values.reduce(0, +)
        }
        let agentCalls = claudeSessions.reduce(0) {
            $0 + ($1.tools["Agent"] ?? 0) + ($1.tools["Task"] ?? 0)
        }
        if mainToolTotal > 200,
           Double(searchCalls) / Double(mainToolTotal) > 0.45,
           Double(agentCalls) < Double(mainToolTotal) * 0.02 {
            advice.append(Item(severity: "medium", key: "adv_delegate",
                               params: ["pct": percentString(Double(searchCalls) / Double(mainToolTotal))]))
        }

        // 5. 同一 Bash コマンドの反復（リトライループ）
        var loops: [(cmd: String, count: Int)] = []
        for s in sessions {
            for (cmd, n) in s.bashCommands where n >= 5 {
                loops.append((cmd, n))
            }
        }
        if let worst = loops.max(by: { $0.count < $1.count }) {
            advice.append(Item(severity: "medium", key: "adv_retry",
                               params: ["count": "\(loops.count)",
                                        "max": "\(worst.count)",
                                        "cmd": String(worst.cmd.prefix(80))]))
        }

        // 6. 頻繁な割り込み
        let totalPrompts = sessions.reduce(0) { $0 + $1.prompts }
        let totalIntr = sessions.reduce(0) { $0 + $1.interruptions }
        if totalPrompts > 30, Double(totalIntr) > Double(totalPrompts) * 0.12 {
            advice.append(Item(severity: "medium", key: "adv_interrupt",
                               params: ["count": "\(totalIntr)", "prompts": "\(totalPrompts)"]))
        }

        // 7. モデルミックス: 高価なモデルでの極小セッション
        let tinyExpensive = sessions.filter { s in
            s.cost > 0 && s.prompts <= 2 && s.output < 2000
                && s.models.contains { model in
                    let family = RetokPricing.modelFamily(model)
                    return family == "fable" || family == "opus"
                }
        }
        if tinyExpensive.count >= 10 {
            let waste = tinyExpensive.reduce(0.0) { $0 + $1.cost }
            advice.append(Item(severity: "low", key: "adv_model_mix",
                               params: ["count": "\(tinyExpensive.count)",
                                        "cost": String(format: "%.2f", waste)]))
        }

        if advice.isEmpty {
            advice.append(Item(severity: "info", key: "adv_ok", params: [:]))
        }
        return (advice, hit)
    }

    /// Python の f"{x:.0%}" 相当（百分率・偶数丸め）。
    private static func percentString(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded(.toNearestOrEven)))%"
    }
}
