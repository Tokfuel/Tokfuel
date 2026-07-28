import Foundation

/// 金額の表示通貨。コストは内部的に常に USD で持ち、表示時だけ変換する。
enum DisplayCurrency: String, CaseIterable, Identifiable {
    case usd, jpy
    var id: String { rawValue }
    var label: String {
        switch self {
        case .usd: return "米ドル ($)"
        case .jpy: return "日本円 (¥)"
        }
    }
}

/// USD 建ての金額を表示通貨でフォーマットする。
/// 通貨設定とレートは UserDefaults から直接読むため、どの actor からでも呼べる。
enum Money {
    static let currencyKey = "displayCurrency"
    static let rateKey = "usdJpyRate"
    static let rateDateKey = "usdJpyRateDate"

    nonisolated static func format(_ usd: Double) -> String {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: currencyKey) == DisplayCurrency.jpy.rawValue {
            let rate = defaults.double(forKey: rateKey)
            if rate > 0 {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 0
                formatter.locale = Locale(identifier: "en_US")   // 桁区切りを , に固定
                let yen = (usd * rate).rounded()
                return "¥" + (formatter.string(from: NSNumber(value: yen))
                              ?? String(format: "%.0f", yen))
            }
            // レート未取得（初回のオフライン等）は USD 表示にフォールバックする。
        }
        return usd >= 100 ? String(format: "$%.0f", usd) : String(format: "$%.2f", usd)
    }
}

/// Frankfurter API (https://frankfurter.dev) から USD→JPY レートを取得する。
/// 日本円表示を選んだときだけ呼ばれる、1 日 1 回キャッシュの唯一の通信機能。
/// 送るのはレートの問い合わせだけで、使用データや個人情報は含まない。
enum ExchangeRateService {
    /// キャッシュが今日のものならスキップし、必要なら取得して UserDefaults に保存する。
    /// 取得できたら true（表示の再描画が必要）。
    @discardableResult
    static func refreshIfNeeded(now: Date = Date()) async -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: Money.currencyKey) == DisplayCurrency.jpy.rawValue
        else { return false }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: now)
        if defaults.string(forKey: Money.rateDateKey) == today,
           defaults.double(forKey: Money.rateKey) > 0 { return false }

        struct Response: Decodable { let rates: [String: Double] }
        guard let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=USD&symbols=JPY"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let rate = (try? JSONDecoder().decode(Response.self, from: data))?.rates["JPY"],
              rate > 0
        else { return false }

        defaults.set(rate, forKey: Money.rateKey)
        defaults.set(today, forKey: Money.rateDateKey)
        return true
    }
}
