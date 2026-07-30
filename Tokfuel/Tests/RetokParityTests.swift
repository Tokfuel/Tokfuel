import Foundation
import Testing
@testable import Tokfuel

/// Python 版 retok とネイティブ移植の突合。実マシンのトランスクリプトに対して両者を走らせ、
/// 主要な数値が一致することを確かめる。python3 と実データが要るため CI では走らせず、
/// `RETOK_PARITY=1 swift test --filter pythonParity` で手元でのみ実行する。
struct RetokParityTests {

    @Test(.enabled(if: ProcessInfo.processInfo.environment["RETOK_PARITY"] != nil))
    func pythonParity() throws {
        let script = try #require(Bundle.module.url(forResource: "retok", withExtension: "py"))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", script.path, "--json", "--days", "30", "--lang", "en"]
        let stdout = Pipe()
        process.standardOutput = stdout
        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try #require(process.terminationStatus == 0, "python retok が失敗（データ無し？）")
        let expected = try JSONDecoder().decode(RetokReport.self, from: data)

        let actual = try RetokAnalyzer.analyze(
            days: 30, lang: "en",
            claudeDirs: RetokAnalyzer.defaultClaudeDirs(),
            codexDirs: RetokAnalyzer.defaultCodexDirs())

        // 2 回の走査の間にも使用量は増え、since も数十秒ずれる（30 日前の境界のエントリが落ちる）。
        // このタイミング差を吸収するため、コスト・件数は 1% の相対誤差で比べ、
        // 進行中の「今日」のバケツは日次比較から除外する。
        func close(_ a: Double, _ b: Double, tolerance: Double = 0.01) -> Bool {
            abs(a - b) <= max(abs(b) * tolerance, 0.01)
        }
        #expect(actual.filesScanned == expected.filesScanned)
        #expect(close(Double(actual.totals.requests), Double(expected.totals.requests)))
        #expect(close(actual.totals.cost, expected.totals.cost),
                "cost: native \(actual.totals.cost) vs python \(expected.totals.cost)")
        #expect(close(Double(actual.totals.prompts), Double(expected.totals.prompts)))
        #expect(close(actual.cacheHitRate, expected.cacheHitRate))
        #expect(Set(actual.perModel.keys) == Set(expected.perModel.keys))
        #expect(Set(actual.daily.keys) == Set(expected.daily.keys))
        let today = RetokTime.localDayString(Date())
        for (day, cost) in expected.daily where day != today {
            let native = actual.daily[day]?.cost ?? -1
            #expect(close(native, cost.cost, tolerance: 0.001),
                    "daily \(day): native \(native) vs python \(cost.cost)")
        }
        #expect(actual.advice.map(\.key) == expected.advice.map(\.key))
        #expect(actual.topSessions.map(\.session) == expected.topSessions.map(\.session))
    }
}
