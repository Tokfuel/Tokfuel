import Foundation

public struct CostSnapshot: Sendable, Equatable {
    public var daily: [String: Double]
    public var byModel: [String: Double]
    public var health: Health = .ok

    public init(daily: [String: Double] = [:], byModel: [String: Double] = [:], health: Health = .ok) {
        self.daily = daily
        self.byModel = byModel
        self.health = health
    }

    public static let empty = CostSnapshot(daily: [:], byModel: [:])

    /// 「本当に $0」と「取れなかったので $0」を呼び出し側が区別できるようにするための状態。
    public enum Health: Sendable, Equatable {
        case ok
        case degraded(Degradation)
    }

    /// 劣化の理由。UI に出す文はここが持つ（ソース名は呼び出し側が前置する）。
    public enum Degradation: Sendable, Equatable {
        case signedOut
        /// 失効させられている。ディスクのトークンは `exp` が先でも失効しうるので、
        case credentialsRejected
        case remoteUnavailable

        /// 1 行で収まる長さに保つ。「金額が実際より低い」ことは注記しない——劣化していれば
        /// 可能性ではなく確実にそうなので、代わりに直し方（何をすれば戻るか）を書く。
        public var message: String {
            switch self {
            case .signedOut:
                return "未サインイン。サインインしてください"
            case .credentialsRejected:
                // 単に再サインインでは足りない。アプリは自分がまだ有効だと思っているので、
                return "サインイン切れ。サインアウトして再サインインしてください"
            case .remoteUnavailable:
                return "使用量 API に接続できません"
            }
        }

        public var isRecoverableBySignIn: Bool {
            switch self {
            case .signedOut, .credentialsRejected: return true
            case .remoteUnavailable: return false
            }
        }
    }

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

    public func sessions(from: String, to: String) async -> [CostSnapshot.Session] { [] }
}
