import Foundation

/// 1 回の取得で得られる日別とモデル別の一貫したスナップショット。
struct CostSnapshot: Sendable, Equatable {
    var daily: [String: Double]
    var byModel: [String: Double]
    /// この取得がどこまで信用できるか。既定は `.ok`（＝金額 0 は「使っていない」の意味）。
    var health: Health = .ok
    /// 使ったが請求されなかったぶん（プランの included 枠、エラーで無課金など）。
    /// 金額としては 0 が正しいので `daily` には足さず、$0 を「使っていない」と誤読させない
    /// ための材料としてだけ持つ。
    var unbilled = UnbilledUsage()
    /// 金額を出せなかったぶん（課金区分も金額欄も読めなかったイベント）。
    /// こちらの 0 は「請求が無い」ではなく「いくらか分からない」なので、UI では区別する。
    var unpriced = UnbilledUsage()

    static let empty = CostSnapshot(daily: [:], byModel: [:])

    /// 合算に入れなかった使用の記録。金額は一切持たない——持てないからここに来ている。
    struct UnbilledUsage: Sendable, Equatable {
        /// モデル ID → トークン数の合計。注意書きに「どのモデルか」を出すために持つ。
        var tokensByModel: [String: Int] = [:]
        /// 該当イベントがあったローカル日付（"YYYY-MM-DD"）。ヒーローの「今日」が
        /// この状態かどうかを日単位で判定するために持つ。
        var days: Set<String> = []

        /// モデルが分からないイベントをまとめるキー。
        static let unknownModelLabel = "モデル不明"

        var isEmpty: Bool { tokensByModel.isEmpty }

        /// 注意書きに並べるモデル名。辞書順にして、同じ取得からは同じ並びが出るようにする。
        var models: [String] { tokensByModel.keys.sorted() }

        func includes(day: String) -> Bool { days.contains(day) }

        mutating func add(model: String?, day: String?, tokens: Int) {
            let key = model.flatMap { $0.isEmpty ? nil : $0 } ?? Self.unknownModelLabel
            tokensByModel[key, default: 0] += tokens
            if let day { days.insert(day) }
        }
    }

    /// 「本当に $0」と「取れなかったので $0」を呼び出し側が区別できるようにするための状態。
    /// 金額そのものは失敗しても 0 に落とす（合算を壊さない）が、その 0 の意味はここが伝える。
    enum Health: Sendable, Equatable {
        /// 想定した経路で取得できた。0 なら本当に 0。
        case ok
        /// 主経路が使えず、表示額が実態より低い可能性がある。
        case degraded(Degradation)
    }

    /// 劣化の理由。UI に出す文はここが持つ（ソース名は呼び出し側が前置する）。
    enum Degradation: Sendable, Equatable {
        /// 認証情報が無い（そのアプリにサインインしていない）。
        case signedOut
        /// 認証情報はあるが拒否された（401 / 403）。トークンが期限切れか、サーバ側で
        /// 失効させられている。ディスクのトークンは `exp` が先でも失効しうるので、
        /// 「サインインし直す」以外に回復手段が無い。
        case credentialsRejected
        /// 呼べなかった（オフライン・タイムアウト・応答形式の変化など）。
        case remoteUnavailable

        /// 1 行で収まる長さに保つ。「金額が実際より低い」ことは注記しない——劣化していれば
        /// 可能性ではなく確実にそうなので、代わりに直し方（何をすれば戻るか）を書く。
        var message: String {
            switch self {
            case .signedOut:
                return "未サインイン。サインインしてください"
            case .credentialsRejected:
                // 単に再サインインでは足りない。アプリは自分がまだ有効だと思っているので、
                // サインアウトでその状態を壊す必要がある（サーバの返す指示と同じ）。
                return "サインイン切れ。サインアウトして再サインインしてください"
            case .remoteUnavailable:
                return "使用量 API に接続できません"
            }
        }

        /// サインインし直せば直る種類か。ポップオーバーがボタンを出すかの判断に使う。
        var isRecoverableBySignIn: Bool {
            switch self {
            case .signedOut, .credentialsRejected: return true
            case .remoteUnavailable: return false
            }
        }
    }

    /// 二次ソースの会話（セッション）1 件ぶんの内訳。`RetokReport.TopSession` と同じ粒度に
    /// そろえてあり、「高コストのセッション」で Claude の行と 1 本のリストに混ぜられる。
    struct Session: Sendable, Equatable, Identifiable {
        /// ソース内で一意な ID（Cursor なら composerId）。
        let id: String
        /// 表示名。会話名が取れないときはソース側が既定の文言を入れる。
        let title: String
        let cost: Double
        /// やり取りの数（Cursor なら bubble 数）。
        let messages: Int
        /// 最終利用日（ローカル "YYYY-MM-DD"）。
        let lastUsed: String
    }
}

/// Claude/retok に加えて合算する二次コスト源のための共通面。
protocol CostDriver: Sendable {
    var id: String { get }
    var displayName: String { get }

    /// ローカルにデータが存在するか（未インストール等なら false）。
    /// false のときは UI・合算のどちらにも一切影響を与えない（zero-setup の劣化と同じ形）。
    var isAvailable: Bool { get }

    /// サインインをやり直せるアプリのバンドル ID。認証を持たないソース（Codex など）は nil。
    /// 劣化がサインイン切れだったとき、ポップオーバーがこのアプリを前面に出すのに使う——
    /// Tokfuel 自身はログイン画面を持たない（他アプリの認証を代行しない）。
    var signInBundleID: String? { get }

    /// [from, to] 区間（両端含む、"YYYY-MM-DD"）のコスト。
    func snapshot(from: String, to: String) async -> CostSnapshot

    /// [from, to] 区間のセッション単位の内訳（任意実装）。
    /// セッションを識別できないソースは既定実装のまま空を返し、UI にも一切現れない。
    func sessions(from: String, to: String) async -> [CostSnapshot.Session]
}

extension CostDriver {
    var signInBundleID: String? { nil }

    func dailyCosts(from: String, to: String) async -> [String: Double] {
        await snapshot(from: from, to: to).daily
    }

    /// セッション単位を持たないソース（Codex 等）の既定。
    func sessions(from: String, to: String) async -> [CostSnapshot.Session] { [] }
}
