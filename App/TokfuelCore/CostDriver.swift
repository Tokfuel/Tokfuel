import Foundation

/// 1 回の取得で得られる日別とモデル別の一貫したスナップショット。
public struct CostSnapshot: Sendable, Equatable {
    public var daily: [String: Double]
    public var byModel: [String: Double]
    /// この取得がどこまで信用できるか。既定は `.ok`（＝金額 0 は「使っていない」の意味）。
    public var health: Health = .ok

    public init(daily: [String: Double] = [:], byModel: [String: Double] = [:], health: Health = .ok) {
        self.daily = daily
        self.byModel = byModel
        self.health = health
    }

    public static let empty = CostSnapshot(daily: [:], byModel: [:])

    /// 「本当に $0」と「取れなかったので $0」を呼び出し側が区別できるようにするための状態。
    /// 金額そのものは失敗しても 0 に落とす（合算を壊さない）が、その 0 の意味はここが伝える。
    public enum Health: Sendable, Equatable {
        /// 想定した経路で取得できた。0 なら本当に 0。
        case ok
        /// 主経路が使えず、表示額が実態より低い可能性がある。
        case degraded(Degradation)
    }

    /// 劣化の理由。UI に出す文はここが持つ（ソース名は呼び出し側が前置する）。
    public enum Degradation: Sendable, Equatable {
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
        public var message: String {
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
        public var isRecoverableBySignIn: Bool {
            switch self {
            case .signedOut, .credentialsRejected: return true
            case .remoteUnavailable: return false
            }
        }
    }

    /// 二次ソースの会話（セッション）1 件ぶんの内訳。`RetokReport.TopSession` と同じ粒度に
    /// そろえてあり、「高コストのセッション」で Claude の行と 1 本のリストに混ぜられる。
    public struct Session: Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        public let cost: Double
        public let messages: Int
        public let lastUsed: String

        public init(id: String, title: String, cost: Double, messages: Int, lastUsed: String) {
            self.id = id
            self.title = title
            self.cost = cost
            self.messages = messages
            self.lastUsed = lastUsed
        }
    }
}

/// Claude/retok に加えて合算する二次コスト源のための共通面。
public protocol CostDriver: Sendable {
    var id: String { get }
    var displayName: String { get }
    var isAvailable: Bool { get }
    var signInBundleID: String? { get }
    func snapshot(from: String, to: String) async -> CostSnapshot
    func sessions(from: String, to: String) async -> [CostSnapshot.Session]
}

public extension CostDriver {
    public var signInBundleID: String? { nil }

    public func dailyCosts(from: String, to: String) async -> [String: Double] {
        await snapshot(from: from, to: to).daily
    }

    /// セッション単位を持たないソース（Codex 等）の既定。
    public func sessions(from: String, to: String) async -> [CostSnapshot.Session] { [] }
}
