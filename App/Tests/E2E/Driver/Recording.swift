import Foundation

/// 前回成功した core6 の挙動記録。存在すればタイムアウトを短縮して再実行を速くする。
struct E2ERecording: Codable {
    struct Scenario: Codable {
        var id: String
        var elapsedMs: Int
        var identifiers: [String]
    }

    var version: Int
    var updatedAt: String
    var launchSettleSeconds: Double
    var pollIntervalSeconds: Double
    var timeoutScale: Double
    var scenarios: [Scenario]
    var requiredIdentifiers: [String]

    static let defaultPath = "App/Tests/E2E/recordings/core6.json"
    static let localCachePath = ".build/e2e/core6-last.json"

    static func load(from preferred: String?) -> E2ERecording? {
        let candidates = [
            preferred,
            localCachePath,
            defaultPath
        ].compactMap { $0 }
        for path in candidates {
            let url = URL(fileURLWithPath: path)
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(E2ERecording.self, from: data) else {
                continue
            }
            fputs("E2E recording loaded: \(path) (timeoutScale=\(decoded.timeoutScale))\n", stderr)
            return decoded
        }
        return nil
    }

    func write(to path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }

    /// コールドタイムアウトに記録の係数を掛け、下限を確保する。
    func scaledTimeout(_ cold: TimeInterval) -> TimeInterval {
        max(0.8, cold * timeoutScale)
    }
}

/// 実行中にシナリオごとの経過と見つかった identifier を集める。
final class E2ERecordingBuilder {
    private var scenarios: [E2ERecording.Scenario] = []
    private var currentID: String?
    private var currentStart = Date()
    private var currentIDs: [String] = []

    func begin(_ id: String) {
        currentID = id
        currentStart = Date()
        currentIDs = []
    }

    func sawIdentifier(_ id: String) {
        if !currentIDs.contains(id) {
            currentIDs.append(id)
        }
    }

    func endCurrent() {
        guard let id = currentID else { return }
        let ms = Int(Date().timeIntervalSince(currentStart) * 1000)
        scenarios.append(.init(id: id, elapsedMs: ms, identifiers: currentIDs))
        currentID = nil
    }

    func build(requiredIdentifiers: [String], previous: E2ERecording?) -> E2ERecording {
        let settle: Double
        if let maxElapsed = scenarios.map(\.elapsedMs).max() {
            // 次回の起動待ちは、最長シナリオの一部を上限に短くする。
            settle = min(previous?.launchSettleSeconds ?? 2.0,
                         max(0.5, Double(maxElapsed) / 1000.0 * 0.4))
        } else {
            settle = previous?.launchSettleSeconds ?? 0.8
        }
        return E2ERecording(
            version: 1,
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            launchSettleSeconds: settle,
            pollIntervalSeconds: previous?.pollIntervalSeconds ?? 0.08,
            timeoutScale: previous?.timeoutScale ?? 0.45,
            scenarios: scenarios,
            requiredIdentifiers: requiredIdentifiers
        )
    }
}
