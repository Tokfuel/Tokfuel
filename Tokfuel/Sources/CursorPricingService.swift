import Foundation

/// Cursor 公式の価格表（<https://cursor.com/docs/models-and-pricing>）を取得し、
/// `CursorPricing` が参照する唯一の単価ソースを最新化する。`Currency.swift` の
/// `ExchangeRateService` と同じ形の、アプリで 2 つ目の通信機能: Cursor がインストールされて
/// いるとき（＝この情報が実際に使われるとき）だけ、1 日 1 回だけ発火する。
///
/// 失敗（オフライン・ページ構成の変更・パース失敗など）はすべて静かに諦め、既存のキャッシュ
/// （無ければ空——`CursorPricing` はハードコードした表を持たないので、未知のモデルと同じ
/// 扱いで 0 になる）にフォールバックする。retok と違い、これはオマケの精度向上でしかないので、
/// 失敗をユーザーに見せる仕組みは持たない。
enum CursorPricingService {
    struct CachedRate: Codable {
        let key: String
        let input: Double
        let output: Double
    }

    private static let cacheKey = "cursorPricingTableCache"
    private static let cacheDateKey = "cursorPricingTableCacheDate"

    /// キャッシュ済みの表（無ければ空）。`CursorPricing.rate(for:)` が参照する唯一のソース。
    /// キー長の降順にソート済み — より具体的なプレフィックスほど先にマッチする。
    static func cachedRates() -> [CachedRate] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let rates = try? JSONDecoder().decode([CachedRate].self, from: data)
        else { return [] }
        return rates
    }

    /// テスト間でキャッシュを衝突させないための排他ロック。UserDefaults 自体はスレッドセーフでも
    /// 「読んで・キーだけ差し替えて・書き戻す」の一連は並行テストだとロスト・アップデートになる。
    private static let testCacheLock = NSLock()

    /// テスト用にキャッシュへ差分マージする（丸ごと置き換えない）。並行実行される他のテストが
    /// 積んだキーは残したまま、自分のキーだけ upsert してキー長降順を保つ。
    /// 使い終わったキーは `removeCachedRatesForTesting(keys:)` で自分の分だけ剥がす。
    static func setCachedRatesForTesting(_ rates: [CachedRate]) {
        testCacheLock.lock()
        defer { testCacheLock.unlock() }
        var current = cachedRates()
        let newKeys = Set(rates.map(\.key))
        current.removeAll { newKeys.contains($0.key) }
        current.append(contentsOf: rates)
        persistForTesting(current)
    }

    /// `setCachedRatesForTesting` で足したキーのうち、指定したものだけ剥がす。
    static func removeCachedRatesForTesting(keys: [String]) {
        testCacheLock.lock()
        defer { testCacheLock.unlock() }
        var current = cachedRates()
        current.removeAll { keys.contains($0.key) }
        persistForTesting(current)
    }

    private static func persistForTesting(_ rates: [CachedRate]) {
        let defaults = UserDefaults.standard
        guard !rates.isEmpty else {
            defaults.removeObject(forKey: cacheKey)
            return
        }
        // parseTable() と同じ不変条件（キー長降順）を保つ。
        let sorted = rates.sorted { $0.key.count > $1.key.count }
        defaults.set(try? JSONEncoder().encode(sorted), forKey: cacheKey)
    }

    /// Cursor がローカルにインストールされていて、かつ今日まだ取得していなければ取得する。
    /// 更新できたら true。
    @discardableResult
    static func refreshIfNeeded(now: Date = Date()) async -> Bool {
        guard FileManager.default.fileExists(atPath: CursorCostDriver.defaultStateDBURL.path)
        else { return false }

        let defaults = UserDefaults.standard
        let today = LocalDay.string(from: now)
        if defaults.string(forKey: cacheDateKey) == today, !cachedRates().isEmpty {
            return false
        }

        guard let url = URL(string: "https://cursor.com/docs/models-and-pricing.md"),
              let data = try? await HTTPClient.data(from: url),
              let markdown = String(data: data, encoding: .utf8)
        else { return false }

        let rates = parseTable(markdown)
        guard !rates.isEmpty, let encoded = try? JSONEncoder().encode(rates) else { return false }

        defaults.set(encoded, forKey: cacheKey)
        defaults.set(today, forKey: cacheDateKey)
        return true
    }

    // MARK: - Markdown テーブルの解析

    /// GFM のパイプテーブル行（`| Model | Provider | Input | Cache write | Cache read | Output | Notes |`）
    /// をパースする。見出し行・区切り行・列数が足りない行・価格が読めない行は静かにスキップする
    /// （ページの見た目が変わってもクラッシュしない——このページは API ではなくドキュメントなので、
    /// 列の追加や並び替えが将来起きても壊れて見えないことを優先する）。
    static func parseTable(_ markdown: String) -> [CachedRate] {
        var rates: [CachedRate] = []
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard trimmedLine.hasPrefix("|") else { continue }

            var cells = trimmedLine.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if cells.first == "" { cells.removeFirst() }
            if cells.last == "" { cells.removeLast() }
            guard cells.count >= 6 else { continue }

            guard let name = modelName(fromCell: cells[0]),
                  let input = price(fromCell: cells[2]),
                  let output = price(fromCell: cells[5])
            else { continue }

            rates.append(CachedRate(key: normalize(name), input: input, output: output))
        }
        // より長い（＝具体的な）キーを先にマッチさせる。ハンドメイドの並び順を用意しなくても、
        // 「B が A のプレフィックスなら B は A より長い」という関係だけで正しい順序になる。
        return rates.sorted { $0.key.count > $1.key.count }
    }

    /// "[Claude 4.5 Sonnet](https://...)" → "Claude 4.5 Sonnet"。リンクでなければそのまま。
    private static func modelName(fromCell cell: String) -> String? {
        guard cell.hasPrefix("["), let closeBracket = cell.firstIndex(of: "]") else {
            return cell.isEmpty ? nil : cell
        }
        let name = cell[cell.index(after: cell.startIndex)..<closeBracket]
        return name.isEmpty ? nil : String(name)
    }

    /// "$3.75" → 3.75。"-"（キャッシュ非対応等）や見出し文字列は nil。
    private static func price(fromCell cell: String) -> Double? {
        guard cell.hasPrefix("$") else { return nil }
        return Double(cell.dropFirst())
    }

    /// "Claude Opus 4.7 (fast mode)" → "claude-opus-4.7"。末尾の注記は落とす。
    private static func normalize(_ name: String) -> String {
        var base = name
        if let parenIndex = base.firstIndex(of: "(") {
            base = String(base[base.startIndex..<parenIndex])
        }
        return base.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }
}
