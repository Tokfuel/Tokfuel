import Foundation

/// 日時ユーティリティ（Claude / Codex スキャナ共用）。
enum RetokTime {
    /// トランスクリプトのタイムスタンプは小数秒あり・なしが混在するので両対応する。
    /// ISO8601FormatStyle は Sendable な値型なので static に置ける。
    private static let isoFractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let iso = Date.ISO8601FormatStyle()

    static func parse(_ timestamp: String?) -> Date? {
        guard let timestamp, !timestamp.isEmpty else { return nil }
        return (try? isoFractional.parse(timestamp)) ?? (try? iso.parse(timestamp))
    }

    private static let gregorian = Calendar(identifier: .gregorian)

    /// ローカルタイムゾーンの YYYY-MM-DD（retok の ts.astimezone().strftime 相当）。
    /// UsageStore.dateString もここへ委譲しており、日次キーの書式はこの 1 箇所が基準。
    /// タイムゾーンは呼び出しごとに解決する（常駐アプリなので稼働中の変更に追随する）。
    static func localDayString(_ date: Date) -> String {
        var calendar = Self.gregorian
        calendar.timeZone = .current
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// JSONL の行分割ユーティリティ（Claude / Codex スキャナ共用）。
/// 行の Range だけを列挙し、コピー（subdata）は呼び出し側が本当に必要な行に限る —
/// ファイル最大級の行（ファイルスナップショット等）を丸ごと複製しないため。
enum RetokJSONL {
    /// data 内の各行の範囲を列挙する（改行は含まない・空行はスキップ）。
    /// 範囲は 0 起点のオフセット。スライス（startIndex ≠ 0）はインデックスがずれるため受け付けない。
    static func forEachLineRange(in data: Data, _ body: (Range<Int>) -> Void) {
        precondition(data.startIndex == 0, "スライスではなくファイル全体の Data を渡すこと")
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            var start = 0
            for i in 0...data.count {
                guard i == data.count || raw[i] == 0x0A else { continue }
                if i > start { body(start..<i) }
                start = i + 1
            }
        }
    }
}

/// ファイル列挙ユーティリティ。retok は glob の深さでファイルを選ぶ（再帰走査ではない）ので、
/// files_scanned と重複計上の挙動を揃えるため同じ深さ指定で列挙する。
enum RetokGlob {
    /// `root/<1 階層>/…` のように、深さを固定してサブディレクトリを列挙する。
    static func directories(in root: URL, depth: Int) -> [URL] {
        var dirs = [root]
        let fm = FileManager.default
        for _ in 0..<depth {
            dirs = dirs.flatMap { dir -> [URL] in
                (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                                             options: [])) ?? []
            }.filter { url in
                // Python の glob 同様、ディレクトリへのシンボリックリンクも辿る
                // （resourceValues の isDirectory はリンク自身を見るので fileExists で解決する）
                var isDir: ObjCBool = false
                return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                    && isDir.boolValue
            }
        }
        return dirs.sorted { $0.path < $1.path }
    }

    /// ディレクトリ直下の .jsonl ファイル。
    static func jsonlFiles(in dir: URL, prefix: String? = nil) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [])) ?? []
        return files
            .filter { $0.pathExtension == "jsonl" }
            .filter { prefix == nil || $0.lastPathComponent.hasPrefix(prefix!) }
            .sorted { $0.path < $1.path }
    }
}

/// ~/.claude/projects のトランスクリプトを走査してセッション・日次・モデル別を積算する
/// （retok.py scan() の Claude 部分の移植）。処理順は retok と厳密に揃える:
/// tool_use 計上 → usage/mid ガード → mid dedup → <synthetic> スキップ → 計上 → TTL 判定 → prevReqTS 更新。
enum RetokClaudeScanner {

    static func scan(dirs: [URL], since: Date, into state: RetokScanState) {
        // メイン: <project>/<session>.jsonl / サブエージェント: <project>/<session>/subagents/*.jsonl
        var files: [(url: URL, isSubagent: Bool)] = []
        for root in dirs {
            for project in RetokGlob.directories(in: root, depth: 1) {
                files += RetokGlob.jsonlFiles(in: project).map { ($0, false) }
                for session in RetokGlob.directories(in: project, depth: 1) {
                    let sub = session.appendingPathComponent("subagents")
                    files += RetokGlob.jsonlFiles(in: sub).map { ($0, true) }
                }
            }
        }

        for (url, isSubagent) in files {
            guard let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate, mtime >= since else { continue }
            state.filesScanned += 1
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { continue }
            scan(file: url, data: data, isSubagent: isSubagent, since: since, into: state)
        }
    }

    private static let assistantMarker = Data("\"type\":\"assistant\"".utf8)
    private static let userMarker = Data("\"type\":\"user\"".utf8)

    private static func scan(file: URL, data: Data, isSubagent: Bool,
                             since: Date, into state: RetokScanState) {
        // assistant / user 行だけをマーカーで前ふるいし、通った行だけをコピーしてデコードする。
        // 真偽の判定はデコード後の type で行う。
        RetokJSONL.forEachLineRange(in: data) { range in
            guard data.range(of: assistantMarker, in: range) != nil
                || data.range(of: userMarker, in: range) != nil else { return }
            process(line: data.subdata(in: range), file: file,
                    isSubagent: isSubagent, since: since, into: state)
        }
    }

    private static func process(line: Data, file: URL, isSubagent: Bool,
                                since: Date, into state: RetokScanState) {
        guard let entry = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let type = entry["type"] as? String,
              type == "assistant" || type == "user",
              let ts = RetokTime.parse(entry["timestamp"] as? String),
              ts >= since else { return }

        let sid: String
        if isSubagent {
            // サブエージェント分は親セッション（subagents/ の 2 つ上のディレクトリ名）へ帰属させる
            sid = file.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
        } else if let id = entry["sessionId"] as? String, !id.isEmpty {
            sid = id
        } else {
            sid = file.deletingPathExtension().lastPathComponent
        }
        let s = state.session(for: sid)
        s.provider = "claude"
        if s.project == nil {
            if let cwd = entry["cwd"] as? String, !cwd.isEmpty {
                s.project = URL(fileURLWithPath: cwd).lastPathComponent
            } else {
                s.project = file.deletingLastPathComponent().lastPathComponent
            }
        }
        if type == "user" {
            if isSubagent {
                // サブエージェント側の "user" はオーケストレータからの指示なので数えない
            } else if isUserPrompt(entry) {
                s.prompts += 1
            } else if isInterruption(entry) {
                s.interruptions += 1
            }
            return
        }

        // assistant エントリ
        let msg = entry["message"] as? [String: Any] ?? [:]
        let usage = msg["usage"] as? [String: Any]
        let mid = msg["id"] as? String
        let sidechain = isSubagent || (entry["isSidechain"] as? Bool ?? false)

        // メインスレッドの tool_use ブロックは usage の有無や <synthetic> に関係なく数える
        // （message.id + block.id で dedup）。sidechain 側の内訳はアドバイスに使わないので数えない。
        if !sidechain, let content = msg["content"] as? [Any] {
            for case let block as [String: Any] in content
            where (block["type"] as? String) == "tool_use" {
                let blockKey = "\(mid ?? "")\u{1F}\(block["id"] as? String ?? "")"
                guard state.seenToolBlocks.insert(blockKey).inserted else { continue }
                let name = block["name"] as? String ?? "?"
                s.tools[name, default: 0] += 1
                if name == "Bash",
                   let cmd = (block["input"] as? [String: Any])?["command"] as? String,
                   !cmd.isEmpty {
                    let trimmed = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
                    s.bashCommands[trimmed, default: 0] += 1
                }
            }
        }

        // Python の truthiness（空 dict / 空文字も偽）に合わせ、空の usage / id も除外する
        guard let usage, !usage.isEmpty, let mid, !mid.isEmpty else { return }
        // 1 レスポンスが同じ message.id で複数行に分かれて記録されるため、走査全体で 1 回だけ数える
        guard state.seenMessageIDs.insert(mid).inserted else { return }

        let model = msg["model"] as? String ?? ""
        if model == "<synthetic>" { return }
        let inp = usage["input_tokens"] as? Int ?? 0
        let out = usage["output_tokens"] as? Int ?? 0
        let read = usage["cache_read_input_tokens"] as? Int ?? 0
        let write = usage["cache_creation_input_tokens"] as? Int ?? 0
        let cc = usage["cache_creation"] as? [String: Any] ?? [:]
        var w5m = cc["ephemeral_5m_input_tokens"] as? Int ?? 0
        let w1h = cc["ephemeral_1h_input_tokens"] as? Int ?? 0
        if w1h + w5m == 0 { w5m = write }  // 内訳が無ければ 5m TTL とみなす
        let cost = RetokPricing.entryCost(modelID: model, input: inp, output: out,
                                          cacheRead: read, write5m: w5m, write1h: w1h)
        let context = inp + read + write

        s.requests += 1
        s.input += inp
        s.output += out
        s.cacheRead += read
        s.cacheWrite += write
        s.cost += cost
        s.models.insert(model)
        if !sidechain {
            s.maxContext = max(s.maxContext, context)

            // TTL 失効ヒューリスティック（メインスレッドのみ）: TTL を超えるギャップの直後に
            // 大きなキャッシュ書込があれば、失効したプレフィックスの再キャッシュとみなす。
            let is1h = w1h > w5m
            let ttl = is1h ? 3600.0 : RetokPricing.cacheTTLSeconds
            if let prev = s.prevReqTS, write > 20_000,
               Double(write) > Double(context) * 0.5,
               ts.timeIntervalSince(prev) > ttl {
                s.expiredCacheWrite += write
                if let family = RetokPricing.modelFamily(model),
                   let p = RetokPricing.price(family: family) {
                    let mult = is1h ? RetokPricing.cacheWrite1h : RetokPricing.cacheWrite5m
                    s.expiredCacheCost += Double(write) * p.input * mult / 1e6
                }
            }
            s.prevReqTS = ts
        }

        state.addDaily(day: RetokTime.localDayString(ts), cost: cost, output: out)
        state.addModel(model, cost: cost, input: inp, output: out,
                       cacheRead: read, cacheWrite: write)
    }

    /// 実際の人間のプロンプトか（tool_result やメタ行を除く）。retok の is_user_prompt 移植。
    static func isUserPrompt(_ entry: [String: Any]) -> Bool {
        if entry["isSidechain"] as? Bool == true { return false }
        guard let msg = entry["message"] as? [String: Any],
              msg["role"] as? String == "user" else { return false }
        let text: String
        if let str = msg["content"] as? String {
            text = str
        } else if let blocks = msg["content"] as? [Any] {
            // dict 以外の要素は無視する（Python の isinstance フィルタと同じ）
            let texts = blocks.compactMap { block -> String? in
                guard let block = block as? [String: Any],
                      block["type"] as? String == "text" else { return nil }
                return block["text"] as? String ?? ""
            }
            guard !texts.isEmpty else { return false }  // tool_result のみのメッセージ
            text = texts.joined(separator: "\n")
        } else {
            return false
        }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if text.hasPrefix("[Request interrupted") { return false }
        if text.hasPrefix("<local-command") || text.hasPrefix("Caveat:") { return false }
        return true
    }

    static func isInterruption(_ entry: [String: Any]) -> Bool {
        guard let msg = entry["message"] as? [String: Any],
              msg["role"] as? String == "user" else { return false }
        if let str = msg["content"] as? String {
            return str.hasPrefix("[Request interrupted")
        }
        if let blocks = msg["content"] as? [Any] {
            return blocks.contains { block in
                guard let block = block as? [String: Any] else { return false }
                return block["type"] as? String == "text"
                    && (block["text"] as? String ?? "").hasPrefix("[Request interrupted")
            }
        }
        return false
    }
}
