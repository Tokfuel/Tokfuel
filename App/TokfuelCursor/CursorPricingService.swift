import Foundation
import TokfuelCore

/// （無ければ空——`CursorPricing` はハードコードした表を持たないので、未知のモデルと同じ
/// 扱いで 0 になる）にフォールバックする。retok と違い、これはオマケの精度向上でしかないので、
public enum CursorPricingService {
    public struct CachedRate: Codable, Sendable {
        public let key: String
        public let input: Double
        public let output: Double

        public init(key: String, input: Double, output: Double) {
            self.key = key
            self.input = input
            self.output = output
        }
    }

    private static let cacheKey = "cursorPricingTableCache"
    private static let cacheDateKey = "cursorPricingTableCacheDate"

    /// キー長の降順にソート済み — より具体的なプレフィックスほど先にマッチする。
    public static func cachedRates() -> [CachedRate] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let rates = try? JSONDecoder().decode([CachedRate].self, from: data)
        else { return [] }
        return rates
    }

    private static let testCacheLock = NSLock()

    public static func setCachedRatesForTesting(_ rates: [CachedRate]) {
        testCacheLock.lock()
        defer { testCacheLock.unlock() }
        var current = cachedRates()
        let newKeys = Set(rates.map(\.key))
        current.removeAll { newKeys.contains($0.key) }
        current.append(contentsOf: rates)
        persistForTesting(current)
    }

    public static func removeCachedRatesForTesting(keys: [String]) {
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
        let sorted = rates.sorted { $0.key.count > $1.key.count }
        defaults.set(try? JSONEncoder().encode(sorted), forKey: cacheKey)
    }

    @discardableResult
    public static func refreshIfNeeded(now: Date = Date()) async -> Bool {
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


    /// （ページの見た目が変わってもクラッシュしない——このページは API ではなくドキュメントなので、
    public static func parseTable(_ markdown: String) -> [CachedRate] {
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
        return rates.sorted { $0.key.count > $1.key.count }
    }

    private static func modelName(fromCell cell: String) -> String? {
        guard cell.hasPrefix("["), let closeBracket = cell.firstIndex(of: "]") else {
            return cell.isEmpty ? nil : cell
        }
        let name = cell[cell.index(after: cell.startIndex)..<closeBracket]
        return name.isEmpty ? nil : String(name)
    }

    private static func price(fromCell cell: String) -> Double? {
        guard cell.hasPrefix("$") else { return nil }
        return Double(cell.dropFirst())
    }

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
