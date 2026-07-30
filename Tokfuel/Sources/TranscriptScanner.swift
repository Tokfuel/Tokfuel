import Foundation

/// Claude Codeのトランスクリプトから、人間のプロンプト数とセッション数だけを集計する。
/// コストとモデル内訳はretokが担当するため、UIで使わないtool_useの分類は保持しない。
enum TranscriptScanner {
    struct FileSummary: Codable {
        var mtime: TimeInterval
        var size: Int
        var days: [String: Int]
    }

    private static var cacheURL: URL {
        let dir = AppSupport.directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("transcript-cache-v2.json")
    }

    static func scan(projectsDir: URL) -> [DailyUsage] {
        let fileManager = FileManager.default
        var cache = (try? JSONDecoder().decode(
            [String: FileSummary].self,
            from: Data(contentsOf: cacheURL)
        )) ?? [:]
        var summaries: [FileSummary] = []
        var seenPaths = Set<String>()

        guard let enumerator = fileManager.enumerator(
            at: projectsDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return [] }

        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let attributes = try? url.resourceValues(
                forKeys: [.contentModificationDateKey, .fileSizeKey]
            ),
            let mtime = attributes.contentModificationDate?.timeIntervalSince1970,
            let size = attributes.fileSize else { continue }

            seenPaths.insert(url.path)
            if let hit = cache[url.path], hit.mtime == mtime, hit.size == size {
                summaries.append(hit)
                continue
            }
            guard let summary = summarize(file: url, mtime: mtime, size: size) else { continue }
            cache[url.path] = summary
            summaries.append(summary)
        }

        cache = cache.filter { seenPaths.contains($0.key) }
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: cacheURL, options: .atomic)
        }

        var totals: [String: DailyUsage] = [:]
        for summary in summaries {
            for (date, prompts) in summary.days where prompts > 0 {
                var day = totals[date] ?? DailyUsage(date: date)
                day.prompts += prompts
                day.sessions += 1
                totals[date] = day
            }
        }
        return totals.values.sorted { $0.date < $1.date }
    }

    private static func summarize(file: URL, mtime: TimeInterval, size: Int) -> FileSummary? {
        guard let data = try? Data(contentsOf: file, options: .mappedIfSafe) else { return nil }
        var days: [String: Int] = [:]

        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let bytes = raw.bindMemory(to: UInt8.self)
            var start = 0
            for index in 0...bytes.count {
                guard index == bytes.count || bytes[index] == 0x0A else { continue }
                if index > start {
                    let line = Data(bytes: raw.baseAddress! + start, count: index - start)
                    if let day = promptDay(in: line) {
                        days[day, default: 0] += 1
                    }
                }
                start = index + 1
            }
        }
        return FileSummary(mtime: mtime, size: size, days: days)
    }

    private static let userMarker = Data("\"type\":\"user\"".utf8)
    private static let toolResultMarker = Data("tool_result".utf8)

    private static func promptDay(in line: Data) -> String? {
        guard line.range(of: userMarker) != nil,
              line.range(of: toolResultMarker) == nil,
              let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              object["isSidechain"] as? Bool != true,
              let message = object["message"] as? [String: Any],
              isHumanPrompt(message["content"]),
              let timestamp = object["timestamp"] as? String,
              timestamp.count >= 10 else { return nil }
        return String(timestamp.prefix(10))
    }

    private static func isHumanPrompt(_ content: Any?) -> Bool {
        if content is String { return true }
        guard let blocks = content as? [[String: Any]], !blocks.isEmpty else { return false }
        return blocks.allSatisfy { ($0["type"] as? String) == "text" }
    }
}
