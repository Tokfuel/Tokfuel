import Foundation

/// ~/.claude/projects のトランスクリプト (JSONL) を直接走査して
/// Skill / MCP / Subagent の利用量とプロンプト数を集計する。
/// フックや外部ツールの設定なしで、アプリを入れるだけで動くためのデータソース。
enum TranscriptScanner {

    /// 1 ファイル分の集計結果。ファイルが変わらない限りキャッシュを再利用する。
    struct FileSummary: Codable {
        var mtime: TimeInterval
        var size: Int
        var project: String    // "org/repo" 形式（ghq パス由来）または cwd 末尾
        var days: [String: DayCounts]
    }

    struct DayCounts: Codable {
        var tools: [String: Int] = [:]   // "Skill:<name>" / "MCP:<tool>" / "Subagent:<type>"
        var prompts: Int = 0
    }

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tokfuel")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("transcript-cache.json")
    }

    /// 全トランスクリプトを走査し、リポジトリ×日単位の RepoUsage 列を返す。
    static func scan(projectsDir: URL) -> [RepoUsage] {
        let fm = FileManager.default

        var cache: [String: FileSummary] = (try? JSONDecoder().decode(
            [String: FileSummary].self, from: Data(contentsOf: cacheURL))) ?? [:]
        var summaries: [FileSummary] = []
        var seenPaths = Set<String>()

        guard let en = fm.enumerator(at: projectsDir, includingPropertiesForKeys:
            [.contentModificationDateKey, .fileSizeKey]) else { return [] }

        for case let url as URL in en where url.pathExtension == "jsonl" {
            guard let attrs = try? url.resourceValues(forKeys:
                [.contentModificationDateKey, .fileSizeKey]),
                  let mtime = attrs.contentModificationDate?.timeIntervalSince1970,
                  let size = attrs.fileSize else { continue }
            seenPaths.insert(url.path)

            if let hit = cache[url.path], hit.mtime == mtime, hit.size == size {
                summaries.append(hit)
                continue
            }
            guard let summary = summarize(file: url, mtime: mtime, size: size) else { continue }
            cache[url.path] = summary
            summaries.append(summary)
        }

        // 消えたファイルはキャッシュからも落とす
        cache = cache.filter { seenPaths.contains($0.key) }
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: cacheURL)
        }

        return aggregate(summaries)
    }

    /// (project, day) 単位にまとめて RepoUsage にする。
    private static func aggregate(_ summaries: [FileSummary]) -> [RepoUsage] {
        struct Key: Hashable { let project: String; let day: String }
        var map: [Key: DayCounts] = [:]
        for s in summaries {
            for (day, counts) in s.days {
                let key = Key(project: s.project, day: day)
                var acc = map[key] ?? DayCounts()
                for (k, v) in counts.tools { acc.tools[k, default: 0] += v }
                acc.prompts += counts.prompts
                map[key] = acc
            }
        }
        return map.map { key, counts in
            let parts = key.project.split(separator: "/")
            let org = parts.count >= 2 ? String(parts[0]) : "unknown"
            let repo = parts.last.map(String.init) ?? key.project
            var session = SessionMetrics()
            session.prompt = counts.prompts
            return RepoUsage(repo: repo, org: org,
                             genre: org == "sansaninc" ? "work" : "personal",
                             date: key.day, tools: counts.tools,
                             session: session, edits: [:])
        }
    }

    /// 1 ファイルを行単位で読み、tool_use とユーザープロンプトだけを拾う。
    /// 大きなファイルでも全行を JSON デコードしないよう、文字列マーカーで前ふるいする。
    private static func summarize(file: URL, mtime: TimeInterval, size: Int) -> FileSummary? {
        guard let data = try? Data(contentsOf: file, options: .mappedIfSafe) else { return nil }

        var project = ""
        var days: [String: DayCounts] = [:]

        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let bytes = raw.bindMemory(to: UInt8.self)
            var start = 0
            for i in 0...bytes.count {
                guard i == bytes.count || bytes[i] == 0x0A else { continue }
                if i > start {
                    let line = Data(bytes: raw.baseAddress! + start, count: i - start)
                    process(line: line, project: &project, days: &days)
                }
                start = i + 1
            }
        }

        if project.isEmpty {
            project = projectName(fromDirName: file.deletingLastPathComponent().lastPathComponent)
        }
        return FileSummary(mtime: mtime, size: size, project: project, days: days)
    }

    private static let toolUseMarker = Data("\"tool_use\"".utf8)
    private static let userMarker = Data("\"type\":\"user\"".utf8)
    private static let toolResultMarker = Data("tool_result".utf8)

    private static func process(line: Data, project: inout String, days: inout [String: DayCounts]) {
        let hasToolUse = line.range(of: toolUseMarker) != nil
        let isUserLine = line.range(of: userMarker) != nil
            && line.range(of: toolResultMarker) == nil

        guard hasToolUse || isUserLine else { return }
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return }

        let day = (obj["timestamp"] as? String).map { String($0.prefix(10)) } ?? ""
        guard !day.isEmpty else { return }

        if project.isEmpty, let cwd = obj["cwd"] as? String {
            project = projectName(fromCwd: cwd)
        }
        // サブエージェント側の記録は親セッションと二重計上になるので tool_use のみ数え、
        // プロンプトは isSidechain でないものだけ数える
        let isSidechain = (obj["isSidechain"] as? Bool) ?? false

        var counts = days[day] ?? DayCounts()
        defer { days[day] = counts }

        if isUserLine, !isSidechain,
           let message = obj["message"] as? [String: Any] {
            // content が文字列 or text ブロックのみ = 人間のプロンプト
            if message["content"] is String {
                counts.prompts += 1
            } else if let content = message["content"] as? [[String: Any]],
                      content.allSatisfy({ ($0["type"] as? String) == "text" }) {
                counts.prompts += 1
            }
        }

        guard hasToolUse,
              let message = obj["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return }

        for block in content where (block["type"] as? String) == "tool_use" {
            guard let name = block["name"] as? String else { continue }
            let input = block["input"] as? [String: Any]

            if name == "Skill", let skill = input?["skill"] as? String {
                // "plugin:skill" 形式は末尾のスキル名に正規化
                let short = skill.split(separator: ":").last.map(String.init) ?? skill
                counts.tools["Skill:\(short)", default: 0] += 1
            } else if name.hasPrefix("mcp__") {
                counts.tools["MCP:\(name)", default: 0] += 1
            } else if name == "Agent" || name == "Task" {
                let type = (input?["subagent_type"] as? String) ?? "general-purpose"
                counts.tools["Subagent:\(type)", default: 0] += 1
            }
        }
    }

    /// cwd（例: ~/ghq/github.com/org/repo/...）から "org/repo" を導く。
    private static func projectName(fromCwd cwd: String) -> String {
        let parts = cwd.split(separator: "/").map(String.init)
        if let ghq = parts.firstIndex(of: "ghq"), parts.count > ghq + 3 {
            return "\(parts[ghq + 2])/\(parts[ghq + 3])"
        }
        // ghq 外は末尾ディレクトリ名のみ
        return parts.last ?? cwd
    }

    /// プロジェクトフォルダ名（パスの "/" を "-" にした形式）からのフォールバック。
    private static func projectName(fromDirName dir: String) -> String {
        let restored = dir.replacingOccurrences(of: "-", with: "/")
        return projectName(fromCwd: restored)
    }
}
