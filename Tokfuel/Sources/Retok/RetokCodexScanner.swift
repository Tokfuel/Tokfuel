import Foundation

/// OpenAI Codex CLI のロールアウト（~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl）を走査する
/// （retok.py scan_codex() の移植）。コストは token_count イベントから最長プレフィックス一致の
/// OpenAI 価格で見積もる。CodexUsageReader（Tools タブ用の軽量集計）とは役割が別。
enum RetokCodexScanner {

    static func scan(dirs: [URL], since: Date, into state: RetokScanState) {
        for root in dirs {
            for dayDir in RetokGlob.directories(in: root, depth: 3) {
                for url in RetokGlob.jsonlFiles(in: dayDir, prefix: "rollout-") {
                    guard let mtime = (try? url.resourceValues(
                        forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                        mtime >= since else { continue }
                    state.filesScanned += 1
                    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe)
                    else { continue }
                    scan(file: url, data: data, since: since, into: state)
                }
            }
        }
    }

    private static func scan(file: URL, data: Data, since: Date, into state: RetokScanState) {
        var sid = file.deletingPathExtension().lastPathComponent
        var model: String?

        RetokJSONL.forEachLineRange(in: data) { range in
            guard let entry = try? JSONSerialization.jsonObject(
                with: data.subdata(in: range)) as? [String: Any] else { return }
            process(entry: entry, sid: &sid, model: &model, since: since, into: state)
        }
    }

    private static func process(entry: [String: Any], sid: inout String, model: inout String?,
                                since: Date, into state: RetokScanState) {
        let etype = entry["type"] as? String
        let payload = entry["payload"] as? [String: Any] ?? [:]
        let ts = RetokTime.parse(entry["timestamp"] as? String)

        // session_meta / turn_context はタイムスタンプ判定より先に処理する（retok と同順）
        if etype == "session_meta" {
            if let id = payload["session_id"] as? String, !id.isEmpty { sid = id }
            let s = state.session(for: sid)
            s.provider = "codex"
            if let cwd = payload["cwd"] as? String, !cwd.isEmpty {
                s.project = URL(fileURLWithPath: cwd).lastPathComponent
            }
            return
        }
        if etype == "turn_context" {
            // 空文字は「モデル不明」扱いで前の値を保つ（Python の truthiness と同じ）
            if let m = payload["model"] as? String, !m.isEmpty { model = m }
            return
        }

        guard let ts, ts >= since else { return }
        let s = state.session(for: sid)
        s.provider = "codex"

        let ptype = payload["type"] as? String
        if etype == "event_msg", ptype == "user_message" {
            s.prompts += 1
            return
        }

        if etype == "response_item", ptype == "function_call" {
            let name = payload["name"] as? String ?? "?"
            s.tools[name, default: 0] += 1
            if ["exec_command", "shell", "local_shell"].contains(name) {
                // arguments は JSON 文字列。cmd は文字列とは限らない（配列のことがある）
                var cmd = ""
                if let args = payload["arguments"] as? String,
                   let parsed = try? JSONSerialization.jsonObject(
                       with: Data(args.utf8)) as? [String: Any],
                   let raw = parsed["cmd"] {
                    cmd = raw as? String ?? String(describing: raw)
                }
                if !cmd.isEmpty {
                    s.bashCommands[cmd.trimmingCharacters(in: .whitespacesAndNewlines),
                                   default: 0] += 1
                }
            }
            return
        }

        guard etype == "event_msg", ptype == "token_count",
              let info = payload["info"] as? [String: Any] else { return }  // rate-limit のみの行は無視
        let last = info["last_token_usage"] as? [String: Any] ?? [:]
        let inpTotal = last["input_tokens"] as? Int ?? 0
        let cached = last["cached_input_tokens"] as? Int ?? 0
        let out = last["output_tokens"] as? Int ?? 0
        guard inpTotal + out > 0 else { return }

        // 再開されたロールアウトは履歴を再生することがある。リクエストごとに一意な
        // 累積カウンタ（生タイムスタンプ文字列と組で）で dedup する。
        let total = (info["total_token_usage"] as? [String: Any])?["total_tokens"] as? Int ?? 0
        let key = "\(sid)\u{1F}\(entry["timestamp"] as? String ?? "")\u{1F}\(total)"
        guard state.seenCodexKeys.insert(key).inserted else { return }

        let mdl = model ?? "gpt-5"
        let cost = RetokPricing.codexCost(modelID: mdl, inputTotal: inpTotal,
                                          cached: cached, output: out)
        s.requests += 1
        s.input += inpTotal - cached
        s.cacheRead += cached
        s.output += out
        s.cost += cost
        s.models.insert(mdl)
        s.maxContext = max(s.maxContext, inpTotal)

        state.addDaily(day: RetokTime.localDayString(ts), cost: cost, output: out)
        state.addModel(mdl, cost: cost, input: inpTotal - cached, output: out,
                       cacheRead: cached, cacheWrite: 0)
    }
}
