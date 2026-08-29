import Foundation

public enum DisplayCurrency: String, CaseIterable, Identifiable {
    case usd, jpy
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .usd: return "米ドル ($)"
        case .jpy: return "日本円 (¥)"
        }
    }
}

/// 通貨設定とレートは UserDefaults から直接読むため、どの actor からでも呼べる。
public enum Money {
    public static let currencyKey = "displayCurrency"
    public static let rateKey = "usdJpyRate"
    public static let rateDateKey = "usdJpyRateDate"

    public nonisolated static func format(_ usd: Double) -> String {
        let defaults = UserDefaults.standard
        let currency = DisplayCurrency(
            rawValue: defaults.string(forKey: currencyKey) ?? ""
        ) ?? .usd
        return format(usd, currency: currency, rate: currentRate(in: defaults))
    }

    public nonisolated static func format(
        _ usd: Double,
        currency: DisplayCurrency,
        rate: Double
    ) -> String {
        if currency == .jpy, rate > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            formatter.locale = Locale(identifier: "en_US")
            let yen = (usd * rate).rounded()
            return "¥" + (formatter.string(from: NSNumber(value: yen))
                          ?? String(format: "%.0f", yen))
        }
        return usd >= 100 ? String(format: "$%.0f", usd) : String(format: "$%.2f", usd)
    }

    public nonisolated static func currentRate(in defaults: UserDefaults = .standard) -> Double {
        defaults.double(forKey: rateKey)
    }

    public nonisolated static func displayAmount(
        forUSD usd: Double,
        currency: DisplayCurrency,
        rate: Double
    ) -> Double {
        currency == .jpy && rate > 0 ? (usd * rate).rounded() : usd
    }

    public nonisolated static func usdAmount(
        fromDisplayAmount amount: Double,
        currency: DisplayCurrency,
        rate: Double
    ) -> Double {
        currency == .jpy && rate > 0 ? amount / rate : amount
    }

    /// ガードにより実質何もしない（値をそのまま返す）。
    public nonisolated static func convert(
        _ amount: Double,
        from: DisplayCurrency,
        to: DisplayCurrency,
        rate: Double
    ) -> Double {
        guard from != to else { return amount }
        return displayAmount(forUSD: usdAmount(fromDisplayAmount: amount, currency: from, rate: rate),
                             currency: to, rate: rate)
    }

    public nonisolated static func unitSymbol(currency: DisplayCurrency, rate: Double) -> String {
        currency == .jpy && rate > 0 ? "¥" : "$"
    }

    public nonisolated static func formatAxis(
        _ displayAmount: Double,
        currency: DisplayCurrency,
        rate: Double
    ) -> String {
        if currency == .jpy, rate > 0 {
            let yen = displayAmount.rounded()
            if abs(yen) >= 10_000 {
                let man = yen / 10_000
                if man == man.rounded() {
                    return "¥\(Int(man))万"
                }
                return String(format: "¥%.1f万", man)
            }
            return "¥\(Int(yen))"
        }
        return String(format: "$%.0f", displayAmount.rounded())
    }
}

public enum ExchangeRateService {
    @discardableResult
    public static func refreshIfNeeded(now: Date = Date()) async -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: Money.currencyKey) == DisplayCurrency.jpy.rawValue
        else { return false }

        let today = LocalDay.string(from: now)
        if defaults.string(forKey: Money.rateDateKey) == today,
           defaults.double(forKey: Money.rateKey) > 0 { return false }

        struct Response: Decodable { let rates: [String: Double] }
        guard let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=USD&symbols=JPY"),
              let data = try? await HTTPClient.data(from: url),
              let rate = (try? JSONDecoder().decode(Response.self, from: data))?.rates["JPY"],
              rate > 0
        else { return false }

        defaults.set(rate, forKey: Money.rateKey)
        defaults.set(today, forKey: Money.rateDateKey)
        return true
    }
}
