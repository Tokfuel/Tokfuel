/// Fixture-only snapshot for the browsable demo. No disk or network I/O.
public struct DemoFixtures: Equatable {
    public struct Day: Equatable {
        public var label: String
        public var claude: Double
        public var cursor: Double
        public init(label: String, claude: Double, cursor: Double) {
            self.label = label
            self.claude = claude
            self.cursor = cursor
        }
    }

    public struct Model: Equatable {
        public var name: String
        public var cost: Double
        public init(name: String, cost: Double) {
            self.name = name
            self.cost = cost
        }
    }

    public struct Session: Equatable {
        public var title: String
        public var cost: Double
        public init(title: String, cost: Double) {
            self.title = title
            self.cost = cost
        }
    }

    public struct Advice: Equatable {
        public var source: String
        public var title: String
        public var detail: String
        public init(source: String, title: String, detail: String) {
            self.source = source
            self.title = title
            self.detail = detail
        }
    }

    public var updatedAt: String
    public var claudeTodayCost: Double
    public var cursorTodayCost: Double
    public var daily: [Day]
    public var periodTotal: Double
    public var promptUnitCost: Double
    public var budgetLimit: Double
    public var budgetSpend: Double
    public var dailyBudgetLimit: Double
    public var warnPercent: Double
    public var claudeModels: [Model]
    public var cursorModels: [Model]
    public var sessions: [Session]
    public var advice: [Advice]

    public var todayTotal: Double { claudeTodayCost + cursorTodayCost }

    public static let sample = DemoFixtures(
        updatedAt: "14:25",
        claudeTodayCost: 12.34,
        cursorTodayCost: 4.20,
        daily: [
            Day(label: "07/30", claude: 8.42, cursor: 0),
            Day(label: "07/31", claude: 12.4, cursor: 2.7),
            Day(label: "08/01", claude: 6.05, cursor: 0),
            Day(label: "08/02", claude: 18.1, cursor: 3.2),
            Day(label: "08/03", claude: 9.5, cursor: 2.3),
            Day(label: "08/04", claude: 20.5, cursor: 4.4),
            Day(label: "08/05", claude: 12.34, cursor: 4.2),
        ],
        periodTotal: 104,
        promptUnitCost: 0.28,
        budgetLimit: 300,
        budgetSpend: 250,
        dailyBudgetLimit: 20,
        warnPercent: 0.8,
        claudeModels: [
            Model(name: "fable-5", cost: 68.30),
            Model(name: "sonnet-5", cost: 20.16),
            Model(name: "haiku-4-5", cost: 11.45),
        ],
        cursorModels: [
            Model(name: "4.5-sonnet", cost: 3.36),
            Model(name: "gpt-5-codex", cost: 0.84),
        ],
        sessions: [
            Session(title: "SwiftUI のレイアウト崩れを直す", cost: 11.20),
            Session(title: "コスト表示の週次グラフ", cost: 8.40),
        ],
        advice: [
            Advice(
                source: "Claude",
                title: "高価格モデルでの小粒セッションが 12 件 ($18.40)",
                detail: "一問一答や軽い確認は Haiku/Sonnet で十分なことが多いです。"
                    + "/model で切り替えるか、軽い用途向けに別プロファイルを用意すると節約できます。"
            )
        ]
    )
}

func demoMoney(_ value: Double) -> String {
    let cents = Int((value * 100.0).rounded())
    let whole = cents / 100
    let frac = abs(cents % 100)
    let fracText = frac < 10 ? "0\(frac)" : "\(frac)"
    return "$\(whole).\(fracText)"
}
