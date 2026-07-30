import Foundation
import Testing
@testable import Tokfuel

/// 7 つのアドバイス規則の閾値検証。閾値は retok.py build_advice() と同一。
struct RetokAdviceTests {

    private func session(_ configure: (RetokSession) -> Void = { _ in }) -> RetokSession {
        let s = RetokSession()
        s.provider = "claude"
        configure(s)
        return s
    }

    private func keys(_ sessions: [RetokSession],
                      totals: RetokAdvice.Totals = RetokAdvice.Totals()) -> [String] {
        RetokAdvice.build(sessions: sessions, totals: totals).advice.map(\.key)
    }

    @Test func キャッシュヒット率が低いと警告() {
        var totals = RetokAdvice.Totals()
        totals.input = 500_000
        totals.cacheRead = 1_000_000
        totals.cacheWrite = 500_000   // hit = 0.5, denom = 2M
        let result = RetokAdvice.build(sessions: [session()], totals: totals)
        #expect(result.advice.first?.key == "adv_cache_hit")
        #expect(result.advice.first?.params["rate"] == "50%")
        #expect(abs(result.hitRate - 0.5) < 1e-12)

        // ヒット率 75% ちょうどは警告しない
        totals.input = 250_000
        totals.cacheRead = 1_500_000
        totals.cacheWrite = 250_000
        #expect(!keys([session()], totals: totals).contains("adv_cache_hit"))

        // 分母 1M 以下は対象外
        totals.input = 500_000
        totals.cacheRead = 100_000
        totals.cacheWrite = 400_000
        #expect(!keys([session()], totals: totals).contains("adv_cache_hit"))
    }

    @Test func TTL失効コストが1ドル超で警告() {
        let s = session { $0.expiredCacheCost = 1.5; $0.expiredCacheWrite = 2_500_000 }
        let result = RetokAdvice.build(sessions: [s], totals: RetokAdvice.Totals())
        #expect(result.advice.first?.key == "adv_ttl")
        #expect(result.advice.first?.params["mtok"] == "2.5")
        #expect(result.advice.first?.params["cost"] == "1.50")

        let cheap = session { $0.expiredCacheCost = 0.9 }
        #expect(!keys([cheap]).contains("adv_ttl"))
    }

    @Test func 大きいコンテキストはプロンプト3以上のセッションのみ警告() {
        let fat = session { $0.maxContext = 250_000; $0.prompts = 3 }
        let result = RetokAdvice.build(sessions: [fat], totals: RetokAdvice.Totals())
        #expect(result.advice.first?.key == "adv_fat_ctx")
        #expect(result.advice.first?.params["max"] == "250")

        let fewPrompts = session { $0.maxContext = 250_000; $0.prompts = 2 }
        #expect(!keys([fewPrompts]).contains("adv_fat_ctx"))
        let small = session { $0.maxContext = 120_000; $0.prompts = 5 }
        #expect(!keys([small]).contains("adv_fat_ctx"))
    }

    @Test func 探索過多かつ委譲不足で警告() {
        let s = session {
            $0.tools = ["Read": 100, "Grep": 20, "Bash": 100]   // search 120/220 ≈ 55%
        }
        #expect(keys([s]).contains("adv_delegate"))

        // サブエージェントを使っていれば警告しない（agent >= total * 0.02）
        let delegating = session {
            $0.tools = ["Read": 100, "Grep": 20, "Bash": 95, "Agent": 5]
        }
        #expect(!keys([delegating]).contains("adv_delegate"))

        // Codex セッションは対象外
        let codex = session {
            $0.provider = "codex"
            $0.tools = ["Read": 300]
        }
        #expect(!keys([codex]).contains("adv_delegate"))
    }

    @Test func 同一コマンド5回以上で警告() {
        let s = session { $0.bashCommands = ["swift build": 7, "ls": 2] }
        let result = RetokAdvice.build(sessions: [s], totals: RetokAdvice.Totals())
        let item = result.advice.first { $0.key == "adv_retry" }
        #expect(item?.params["max"] == "7")
        #expect(item?.params["cmd"] == "swift build")

        let ok = session { $0.bashCommands = ["swift build": 4] }
        #expect(!keys([ok]).contains("adv_retry"))
    }

    @Test func 割り込みが12percent超で警告() {
        let s = session { $0.prompts = 31; $0.interruptions = 4 }
        #expect(keys([s]).contains("adv_interrupt"))

        let few = session { $0.prompts = 31; $0.interruptions = 3 }   // 3/31 < 0.12
        #expect(!keys([few]).contains("adv_interrupt"))
        let smallSample = session { $0.prompts = 30; $0.interruptions = 30 }
        #expect(!keys([smallSample]).contains("adv_interrupt"))
    }

    @Test func 高価モデルの極小セッションが10件以上で警告() {
        func tiny() -> RetokSession {
            session { $0.cost = 0.1; $0.prompts = 1; $0.output = 100
                      $0.models = ["claude-fable-5"] }
        }
        let sessions = (0..<10).map { _ in tiny() }
        let result = RetokAdvice.build(sessions: sessions, totals: RetokAdvice.Totals())
        let item = result.advice.first { $0.key == "adv_model_mix" }
        #expect(item?.params["count"] == "10")
        #expect(item?.params["cost"] == "1.00")

        #expect(!keys((0..<9).map { _ in tiny() }).contains("adv_model_mix"))

        // Haiku のみの極小セッションは対象外
        let cheap = (0..<10).map { _ in
            session { $0.cost = 0.1; $0.prompts = 1; $0.output = 100
                      $0.models = ["claude-haiku-4-5"] }
        }
        #expect(!keys(cheap).contains("adv_model_mix"))
    }

    @Test func 指摘が無ければadv_ok() {
        #expect(keys([session()]) == ["adv_ok"])
    }
}
