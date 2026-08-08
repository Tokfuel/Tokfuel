import JavaScriptKit

@main
struct TokfuelDemo {
    static func main() {
        let document = JSObject.global.document
        guard let root = document.getElementById("app").object else {
            if let body = document.body.object {
                _ = body.insertAdjacentHTML!(
                    "beforeend",
                    #"<p class="loading">Missing #app mount point.</p>"#
                )
            }
            return
        }

        let state = DemoState()
        render(into: root, state: state)

        let hashchange = JSClosure { _ in
            state.syncFromHash()
            render(into: root, state: state)
            return .undefined
        }
        _ = JSObject.global.window.addEventListener("hashchange", hashchange)
        _ = Unmanaged.passRetained(hashchange)
    }
}

final class DemoState {
    var screen: Screen = .home
    var adviceOpen = false
    let fixtures = FixtureData.embedded

    enum Screen: String {
        case home, settings, about
    }

    init() {
        syncFromHash()
    }

    func syncFromHash() {
        let hash = JSObject.global.location.hash.string ?? ""
        let raw = hash.hasPrefix("#") ? String(hash.dropFirst()) : hash
        screen = Screen(rawValue: raw.isEmpty ? "home" : raw) ?? .home
    }

    func navigate(_ screen: Screen) {
        JSObject.global.location.hash = .string(screen.rawValue)
    }
}

struct FixtureData {
    struct Advice {
        let title: String
        let detail: String
    }

    struct Settings {
        let currency: String
        let costSourceMode: String
        let dailyBudget: Double
        let monthlyBudget: Double
        let appearance: String
    }

    struct About {
        let name: String
        let tagline: String
        let version: String
        let credits: [String]
    }

    let todayCost: Double
    let claudeTodayCost: Double
    let cursorTodayCost: Double
    let dailyCosts: [Double]
    let dayLabels: [String]
    let modelCosts: [(name: String, cost: Double)]
    let budgetLimit: Double
    let budgetSpend: Double
    let dailyBudgetLimit: Double
    let periodLabel: String
    let advice: Advice
    let settings: Settings
    let about: About

    /// Mirrors Demo/fixtures.json (and ScreenshotRenderer fixture numbers).
    static let embedded = FixtureData(
        todayCost: 12.34,
        claudeTodayCost: 12.34,
        cursorTodayCost: 4.20,
        dailyCosts: [8.42, 15.10, 6.05, 21.30, 11.80, 24.90, 12.34],
        dayLabels: ["月", "火", "水", "木", "金", "土", "日"],
        modelCosts: [
            ("claude-fable-5", 68.30),
            ("claude-sonnet-5", 20.16),
            ("claude-haiku-4-5-20251001", 11.45),
        ].sorted { $0.1 > $1.1 },
        budgetLimit: 300,
        budgetSpend: 250,
        dailyBudgetLimit: 20,
        periodLabel: "今週",
        advice: Advice(
            title: "高価格モデルでの小粒セッションが 12 件 ($18.40)",
            detail: "一問一答や軽い確認は Haiku/Sonnet で十分なことが多いです。"
                + "/model で切り替えるか、軽い用途向けに別プロファイルを用意すると節約できます。"
        ),
        settings: Settings(
            currency: "USD",
            costSourceMode: "並べて表示",
            dailyBudget: 20,
            monthlyBudget: 300,
            appearance: "ダーク"
        ),
        about: About(
            name: "Tokfuel",
            tagline: "See what AI coding costs you, from the menu bar.",
            version: "demo",
            credits: [
                "retok © Daiki Matsudate (MIT)",
                "Frankfurter API (optional USD→JPY)",
            ]
        )
    )
}

func money(_ value: Double) -> String {
    let cents = Int((value * 100.0).rounded())
    let whole = cents / 100
    let frac = abs(cents % 100)
    let fracText = frac < 10 ? "0\(frac)" : "\(frac)"
    return "$\(whole).\(fracText)"
}

func escapeHTML(_ text: String) -> String {
    var out = ""
    out.reserveCapacity(text.count)
    for ch in text {
        switch ch {
        case "&": out += "&amp;"
        case "<": out += "&lt;"
        case ">": out += "&gt;"
        case "\"": out += "&quot;"
        default: out.append(ch)
        }
    }
    return out
}

func render(into root: JSObject, state: DemoState) {
    let html: String
    switch state.screen {
    case .home:
        html = homeHTML(state.fixtures, adviceOpen: state.adviceOpen)
    case .settings:
        html = settingsHTML(state.fixtures)
    case .about:
        html = aboutHTML(state.fixtures)
    }

    root.innerHTML = .string(html)
    root.className = .string("chrome \(state.screen.rawValue)")
    bindClicks(root: root, state: state)
}

func bindClicks(root: JSObject, state: DemoState) {
    if let toggle = root.querySelector!("#advice-toggle").object {
        let closure = JSClosure { _ in
            state.adviceOpen.toggle()
            render(into: root, state: state)
            return .undefined
        }
        _ = toggle.addEventListener!("click", closure)
        _ = Unmanaged.passRetained(closure)
    }

    let buttons = root.querySelectorAll!("[data-nav]")
    let length = Int(buttons.length.number ?? 0)
    for index in 0..<length {
        guard let button = buttons[index].object else { continue }
        let target = button.getAttribute!("data-nav").string ?? "home"
        let closure = JSClosure { _ in
            state.navigate(DemoState.Screen(rawValue: target) ?? .home)
            return .undefined
        }
        _ = button.addEventListener!("click", closure)
        _ = Unmanaged.passRetained(closure)
    }
}

func homeHTML(_ data: FixtureData, adviceOpen: Bool) -> String {
    let maxDay = data.dailyCosts.max() ?? 1
    let bars = zip(data.dailyCosts, data.dayLabels).map { cost, label in
        let h = max(2, Int(((cost / maxDay) * 72).rounded()))
        return """
        <div class="bar-col"><div class="bar" style="height:\(h)px"></div>\
        <span class="bar-label">\(escapeHTML(label))</span></div>
        """
    }.joined()

    let maxModel = data.modelCosts.map(\.cost).max() ?? 1
    let models = data.modelCosts.map { name, cost in
        """
        <div class="model-row">
          <div class="model-head"><span class="model-name">\(escapeHTML(name))</span>\
          <span>\(money(cost))</span></div>
          <div class="meter"><span style="width:\((cost / maxModel) * 100)%"></span></div>
        </div>
        """
    }.joined()

    let dailyFrac = min(1, data.todayCost / data.dailyBudgetLimit)
    let monthFrac = min(1, data.budgetSpend / data.budgetLimit)
    let monthWarn = monthFrac >= 0.8

    return """
    <div class="scroll">
      <div class="caption">今日</div>
      <div class="hero-amount">\(money(data.todayCost))</div>
      <div class="side-caption">Claude \(money(data.claudeTodayCost)) · Cursor \(money(data.cursorTodayCost))</div>
      <div class="section">
        <div class="budget-row">
          <div class="budget-head"><span>予算 (今日)</span>\
          <span>\(money(data.todayCost)) / \(money(data.dailyBudgetLimit))</span></div>
          <div class="meter"><span style="width:\(dailyFrac * 100)%"></span></div>
        </div>
        <div class="budget-row">
          <div class="budget-head"><span>予算 (今月)</span>\
          <span>\(money(data.budgetSpend)) / \(money(data.budgetLimit))</span></div>
          <div class="meter \(monthWarn ? "warn" : "")"><span style="width:\(monthFrac * 100)%"></span></div>
        </div>
      </div>
      <div class="section">
        <div class="section-title">推移 · \(escapeHTML(data.periodLabel))</div>
        <div class="bars">\(bars)</div>
      </div>
      <div class="section">
        <div class="section-title">モデル別</div>
        \(models)
      </div>
      <div class="section">
        <button type="button" class="disclosure" id="advice-toggle" aria-expanded="\(adviceOpen)">
          <div class="disclosure-head"><span>節約のヒント</span><span class="chevron">›</span></div>
        </button>
        <div class="advice-body" \(adviceOpen ? "" : "hidden")>
          <div class="advice-title">\(escapeHTML(data.advice.title))</div>
          \(escapeHTML(data.advice.detail))
        </div>
      </div>
    </div>
    <div class="footer">
      <button type="button" class="btn" data-nav="settings">設定</button>
      <button type="button" class="btn" data-nav="about">About</button>
    </div>
    """
}

func settingsHTML(_ data: FixtureData) -> String {
    let s = data.settings
    return """
    <div class="scroll">
      <div class="nav-title">設定</div>
      <p class="caption" style="margin:8px 0 16px">フィクスチャ表示のみ。変更は保存されません。</p>
      <ul class="settings-list">
        <li><span>通貨</span><span class="value">\(escapeHTML(s.currency))</span></li>
        <li><span>コストソース</span><span class="value">\(escapeHTML(s.costSourceMode))</span></li>
        <li><span>日次予算</span><span class="value">\(money(s.dailyBudget))</span></li>
        <li><span>月次予算</span><span class="value">\(money(s.monthlyBudget))</span></li>
        <li><span>外観</span><span class="value">\(escapeHTML(s.appearance))</span></li>
      </ul>
    </div>
    <div class="footer">
      <button type="button" class="btn primary" data-nav="home">戻る</button>
    </div>
    """
}

func aboutHTML(_ data: FixtureData) -> String {
    let a = data.about
    let credits = a.credits.map { "<li><span>\(escapeHTML($0))</span></li>" }.joined()
    return """
    <div class="scroll">
      <div class="about-hero">
        <p class="about-name">\(escapeHTML(a.name))</p>
        <p class="caption">\(escapeHTML(a.tagline))</p>
        <p class="caption">Version \(escapeHTML(a.version))</p>
      </div>
      <ul class="about-list">\(credits)</ul>
    </div>
    <div class="footer">
      <button type="button" class="btn primary" data-nav="home">戻る</button>
    </div>
    """
}
