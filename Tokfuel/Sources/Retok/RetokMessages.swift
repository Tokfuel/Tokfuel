import Foundation

/// retok.py の i18n 移植。英語を正とし、他言語は同梱の locales/<tag>.json（retok 上流由来）で
/// 上書きする。アプリの JSON レポートが使うのはアドバイス文言と no_transcripts のみなので、
/// ターミナル描画用のキーは移植していない。
struct RetokMessages {
    /// retok.py の EN 辞書からアプリが使うキーのみを逐語移植したもの。
    static let english: [String: String] = [
        "no_transcripts": "No transcripts found in the selected period.",

        "adv_cache_hit_title": "Cache hit rate is low ({rate})",
        "adv_cache_hit_detail":
            "Cache reads cost one tenth of regular input. The usual cause of a low "
            + "hit rate is response gaps longer than the cache TTL. Batch your "
            + "instructions into a single message instead of trickling them in, and "
            + "the hit rate goes up.",

        "adv_ttl_title": "Re-caching after cache TTL expiry: ~{mtok}M tokens (${cost})",
        "adv_ttl_detail":
            "Returning to a session left idle beyond the cache TTL (usually 1 hour) "
            + "re-caches the entire context at twice the input rate. Before resuming "
            + "after a break, run /compact to shrink the context — or, for a new "
            + "task, start fresh with /clear or a new session.",

        "adv_fat_ctx_title": "{count} sessions exceeded {limit}k tokens of context (max {max}k)",
        "adv_fat_ctx_detail":
            "The larger the context, the more every single request pays in cache "
            + "reads and rebuilds. Run /clear between tasks, and /compact when you "
            + "need continuity within a long-running one.",

        "adv_delegate_title": "Heavy exploration on the main thread (Read/Grep/Glob = {pct} of tool calls)",
        "adv_delegate_detail":
            "Bulk file exploration inflates the main context and taxes every "
            + "subsequent request. Delegate searches to subagents (Task/Explore) so "
            + "intermediate results never enter the main context — ask for the "
            + "conclusion, not the file dumps.",

        "adv_retry_title": "Repeated identical commands detected ({count} cases, up to {max} times)",
        "adv_retry_detail":
            "Example: `{cmd}` — retrying the same failing build or test burns "
            + "tokens. After two failed fixes, change the approach and ask for a "
            + "diagnosis of the root cause first.",

        "adv_interrupt_title": "Frequent user interruptions ({count} out of {prompts} prompts)",
        "adv_interrupt_detail":
            "Frequent interruptions are a sign the work is drifting from your "
            + "intent. Include the scope, non-goals, and completion criteria in the "
            + "first prompt, and use Plan Mode for uncertain tasks.",

        "adv_model_mix_title": "{count} tiny sessions on premium models (${cost})",
        "adv_model_mix_detail":
            "One-shot questions and quick checks are usually fine on Haiku or "
            + "Sonnet. Switch with /model, or keep a separate profile for light "
            + "tasks.",

        "adv_ok_title": "No major inefficiencies detected",
        "adv_ok_detail":
            "Cache hit rate, context sizes, and tool usage distribution all look "
            + "healthy. Keep it up.",
    ]

    private let messages: [String: String]

    /// 同梱ロケールの一覧（"ja"、"zh-CN" など）。バンドル内容は不変なので 1 度だけ列挙する。
    static let availableLocales: Set<String> = {
        let urls = Bundle.module.urls(forResourcesWithExtension: "json",
                                      subdirectory: "locales") ?? []
        return Set(urls.map { $0.deletingPathExtension().lastPathComponent })
    }()

    /// 言語タグを同梱ロケールへ正規化する（retok の resolve_lang と同じ:
    /// 完全一致 → 基底言語 → 基底言語で始まる別名 → "en"）。
    static func resolveLang(_ requested: String) -> String {
        let tag = requested.split(separator: ".").first.map(String.init) ?? requested
        let parts = tag.replacingOccurrences(of: "_", with: "-").split(separator: "-")
        guard let first = parts.first else { return "en" }
        let base = first.lowercased()
        let norm = parts.count == 1 ? base : "\(base)-\(parts[1].uppercased())"

        let available = availableLocales
        if available.contains(norm) { return norm }
        if available.contains(base) { return base }
        if let alias = available.sorted().first(where: { $0.lowercased().hasPrefix(base + "-") }) {
            return alias
        }
        return "en"
    }

    init(lang: String) {
        var msgs = Self.english
        if lang != "en",
           let url = Bundle.module.url(forResource: lang, withExtension: "json",
                                       subdirectory: "locales"),
           let data = try? Data(contentsOf: url),
           let overrides = try? JSONDecoder().decode([String: String].self, from: data) {
            msgs.merge(overrides) { _, new in new }
        }
        messages = msgs
    }

    /// キーの文言を取り、"{name}" プレースホルダを params で置換する。
    /// キーが無ければキー文字列そのものを返す（retok と同じフォールバック）。
    /// messages は常に english を含むので、二段フォールバックは不要。
    func format(_ key: String, params: [String: String] = [:]) -> String {
        var text = messages[key] ?? key
        for (name, value) in params {
            text = text.replacingOccurrences(of: "{\(name)}", with: value)
        }
        return text
    }
}
