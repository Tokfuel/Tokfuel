import Foundation
import Testing
@testable import Tokfuel

/// Cursor 由来の「節約のヒント」の判定（TF-0078）。しきい値の境目と、
/// 根拠にできないデータからは何も言わないことを見る。
struct CursorAdviceTests {
    private func keys(_ hints: [RetokReport.Advice]) -> [String] { hints.map(\.key) }

    // MARK: - 高単価モデルへの偏り

    @Test func 最上位モデルが六割ちょうどなら偏りとして出す() {
        let hint = CursorAdvice.dominantModelHint(
            modelCosts: ["claude-4.5-sonnet": 6, "gpt-5-codex": 4])
        #expect(hint?.key == CursorAdvice.Key.dominantModel)
        #expect(hint?.severity == "info")
        // 割合は整数％で、モデル名とともにタイトルに出る。
        #expect(hint?.title == "claude-4.5-sonnet が Cursor コストの 60% を占めています")
    }

    @Test func 六割に届かなければ偏りとして出さない() {
        #expect(CursorAdvice.dominantModelHint(
            modelCosts: ["claude-4.5-sonnet": 5.99, "gpt-5-codex": 4.01]) == nil)
    }

    @Test func 値付けできないモデルは偏りの分母から外す() {
        // $0 のモデルを分母に入れても割合は変わらないが、最上位として選ばれてはいけない。
        let hint = CursorAdvice.dominantModelHint(
            modelCosts: ["claude-4.5-sonnet": 8, "gpt-5-codex": 2, "composer-1": 0])
        #expect(hint?.title.hasPrefix("claude-4.5-sonnet") == true)
    }

    @Test func コストがゼロだけなら偏りを判定しない() {
        #expect(CursorAdvice.dominantModelHint(modelCosts: ["composer-1": 0]) == nil)
        #expect(CursorAdvice.dominantModelHint(modelCosts: [:]) == nil)
    }

    // MARK: - 値付けできないモデル

    @Test func 価格表に無いモデルがあれば高い深刻度で出す() {
        let hint = CursorAdvice.unpricedModelsHint(
            modelCosts: ["claude-4.5-sonnet": 8, "composer-1": 0, "auto": 0])
        #expect(hint?.key == CursorAdvice.Key.unpricedModels)
        #expect(hint?.severity == "high")
        #expect(hint?.title == "2 件のモデルの金額が出ず、コストが実際より小さく出ています")
        // 対象は名前で挙げる（どのモデルを避ければよいかが分かる）。
        #expect(hint?.detail.contains("auto, composer-1") == true)
    }

    /// ダッシュボード経路では金額の出ないイベントが `modelCosts` に載らない（#91）。
    @Test func 金額が出なかったモデルは内訳に無くても出す() {
        let hint = CursorAdvice.unpricedModelsHint(
            modelCosts: ["claude-4.5-sonnet": 8],
            unpricedModels: ["composer-2.5-fast", "claude-4.5-sonnet"])
        #expect(hint?.title == "1 件のモデルの金額が出ず、コストが実際より小さく出ています")
        #expect(hint?.detail.contains("composer-2.5-fast") == true)
    }

    @Test func すべて値付けできていれば出さない() {
        #expect(CursorAdvice.unpricedModelsHint(
            modelCosts: ["claude-4.5-sonnet": 8, "gpt-5-codex": 2]) == nil)
    }

    // MARK: - Cursor の比率

    @Test func 五割ちょうどでは比率のヒントを出さない() {
        // 「50% を超えるとき」なので、ちょうど半分は対象外。
        #expect(CursorAdvice.shareHint(cursorTotal: 50, claudeTotal: 50) == nil)
    }

    @Test func 五割を超えたら比率のヒントを出す() {
        let hint = CursorAdvice.shareHint(cursorTotal: 50.01, claudeTotal: 49.99)
        #expect(hint?.key == CursorAdvice.Key.share)
        #expect(hint?.severity == "info")
        #expect(hint?.title == "期間コストの 50% は Cursor です")
    }

    @Test func 両方ゼロなら比率を判定しない() {
        #expect(CursorAdvice.shareHint(cursorTotal: 0, claudeTotal: 0) == nil)
    }

    // MARK: - 合成

    @Test func 条件がそろえば三つとも出る() {
        let hints = CursorAdvice.hints(for: .init(
            modelCosts: ["claude-4.5-sonnet": 80, "gpt-5-codex": 20, "composer-1": 0],
            cursorTotal: 100,
            claudeTotal: 10))
        #expect(keys(hints).sorted() == [
            CursorAdvice.Key.dominantModel,
            CursorAdvice.Key.share,
            CursorAdvice.Key.unpricedModels
        ].sorted())
    }

    @Test func 劣化しているときは一件も出さない() {
        let input = CursorAdvice.Input(
            modelCosts: ["claude-4.5-sonnet": 80, "gpt-5-codex": 20, "composer-1": 0],
            cursorTotal: 100,
            claudeTotal: 10,
            isDegraded: true)
        #expect(CursorAdvice.hints(for: input).isEmpty)
    }

    @Test func データが一件も無ければ出さない() {
        // 「本当に $0」と「取れなかった」を区別できないので、0 からは何も言わない。
        #expect(CursorAdvice.hints(for: .init(claudeTotal: 120)).isEmpty)
    }

    @Test func 日別しか無くてもモデル別に依らない判定は出る() {
        let hints = CursorAdvice.hints(for: .init(cursorTotal: 30, claudeTotal: 10))
        #expect(keys(hints) == [CursorAdvice.Key.share])
    }

    @Test func 値付けできないモデルだけでもそのヒントは出す() {
        // 全モデルが $0 なら合計も $0 だが、まさにその理由を伝えるヒントは要る。
        let hints = CursorAdvice.hints(for: .init(modelCosts: ["composer-1": 0], cursorTotal: 0))
        #expect(keys(hints) == [CursorAdvice.Key.unpricedModels])
    }

    @Test func 割合は四捨五入した整数パーセントで出す() {
        #expect(CursorAdvice.percent(0.7384) == "74%")
        #expect(CursorAdvice.percent(0.5) == "50%")
        #expect(CursorAdvice.percent(1) == "100%")
    }
}

/// `UsageStore` 側の合成 — ソースの選択による抑止、severity 優先の並び、劣化時の抑止。
@MainActor
struct AdviceCompositionTests {
    private static func report(claudeTotal: Double,
                               advice: [RetokReport.Advice] = []) -> RetokReport {
        RetokReport(
            periodDays: 7, filesScanned: 0,
            totals: RetokReport.Totals(cost: claudeTotal),
            cacheHitRate: 0, perModel: [:], daily: [:],
            advice: advice, topSessions: [])
    }

    private static let claudeAdvice = RetokReport.Advice(
        severity: "medium", key: "adv_model_mix", title: "Claude 側のヒント", detail: "詳細")

    /// 実ユーザーの状態に触れないよう、UserDefaults はテスト専用ドメインを作って使い捨てる。
    /// store には Cursor 由来の 3 ヒントすべてが立つデータを積む（表示窓に収まる今日ぶん）。
    private static func withStore(mode: CostSourceMode,
                                  health: CostSnapshot.Health = .ok,
                                  _ body: (UsageStore) -> Void) {
        let name = "tokfuel-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = AppSettings(defaults: defaults)
        settings.costSourceMode = mode
        let store = UsageStore(settings: settings, defaults: defaults, costDrivers: [])
        store.driverDailyByID = ["cursor": [UsageStore.dateString(Date()): 100]]
        store.driverModelByID = ["cursor": ["claude-4.5-sonnet": 80,
                                            "gpt-5-codex": 20,
                                            "composer-1": 0]]
        store.driverHealthByID = ["cursor": health]
        body(store)
    }

    @Test func 合算では両ソースが並ぶ() {
        Self.withStore(mode: .combined) { store in
            let items = store.adviceItems(for: Self.report(claudeTotal: 10,
                                                           advice: [Self.claudeAdvice]))
            #expect(items.map(\.source).contains("Claude"))
            #expect(items.map(\.source).contains("Cursor"))
        }
    }

    @Test func 深刻度の高い順にソース名の順で並ぶ() {
        Self.withStore(mode: .combined) { store in
            let items = store.adviceItems(for: Self.report(claudeTotal: 10,
                                                           advice: [Self.claudeAdvice]))
            // high（Cursor の値付け不能）→ medium（Claude）→ info（Cursor の残り 2 件）。
            #expect(items.first?.advice.key == CursorAdvice.Key.unpricedModels)
            #expect(items.map(\.advice.severity) == ["high", "medium", "info", "info"])
            // 同じ severity ならソース名 → キーの順。
            #expect(items.suffix(2).map(\.advice.key) == [CursorAdvice.Key.dominantModel,
                                                          CursorAdvice.Key.share])
        }
    }

    @Test func ClaudeのみではCursor由来を出さない() {
        Self.withStore(mode: .claudeOnly) { store in
            let items = store.adviceItems(for: Self.report(claudeTotal: 10,
                                                           advice: [Self.claudeAdvice]))
            #expect(items.map(\.source) == ["Claude"])
        }
    }

    @Test func Cursorのみではretok由来を出さない() {
        Self.withStore(mode: .cursorOnly) { store in
            let items = store.adviceItems(for: Self.report(claudeTotal: 10,
                                                           advice: [Self.claudeAdvice]))
            #expect(Set(items.map(\.source)) == ["Cursor"])
            #expect(items.count == 3)
        }
    }

    /// 取得が劣化していれば、金額が揃っていても Cursor 由来は出さない。
    /// 抑止は `CostSnapshot.health`（TF-0073）経由で効く。
    @Test func 劣化していればCursor由来だけが消える() {
        for reason: CostSnapshot.Degradation in [.signedOut, .credentialsRejected,
                                                 .remoteUnavailable] {
            Self.withStore(mode: .combined, health: .degraded(reason)) { store in
                #expect(store.cursorFetchDegraded)
                let items = store.adviceItems(for: Self.report(claudeTotal: 10,
                                                               advice: [Self.claudeAdvice]))
                #expect(items.map(\.source) == ["Claude"])
            }
        }
    }

    @Test func 取得できていればCursor由来を出す() {
        // 上の抑止が「health を見ている」ことの対（.ok では消えない）。
        Self.withStore(mode: .combined, health: .ok) { store in
            #expect(!store.cursorFetchDegraded)
            let items = store.adviceItems(for: Self.report(claudeTotal: 10,
                                                           advice: [Self.claudeAdvice]))
            #expect(items.contains { $0.source == "Cursor" })
        }
    }

    @Test func 確度の報告が無ければ劣化とみなさない() {
        // 二次ソースを持たない環境（driverHealthByID が空）で助言が消えてはいけない。
        Self.withStore(mode: .combined) { store in
            store.driverHealthByID = [:]
            #expect(!store.cursorFetchDegraded)
            #expect(store.adviceItems(for: Self.report(claudeTotal: 10))
                .contains { $0.source == "Cursor" })
        }
    }

    @Test func 表示窓の外のCursorコストは比率に数えない() {
        Self.withStore(mode: .combined) { store in
            // 予算窓の補完で入りうる古い日付だけにする（表示窓は 7 日）。
            store.driverDailyByID = ["cursor": ["2020-01-01": 1000]]
            store.driverModelByID = [:]
            #expect(store.adviceItems(for: Self.report(claudeTotal: 10)).isEmpty)
        }
    }
}
