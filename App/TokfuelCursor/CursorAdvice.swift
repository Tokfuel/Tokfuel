import Foundation
import TokfuelCore

public enum CursorAdvice {
    public static let sourceLabel = "Cursor"

    public static let dominantModelShare = 0.60
    public static let cursorShareOfTotal = 0.50

    /// `RetokReport.Advice.key`。retok 側のキー（`adv_*`）と衝突しない接頭辞にする。
    public enum Key {
        static let dominantModel = "cursor_dominant_model"
        static let unpricedModels = "cursor_unpriced_models"
        static let share = "cursor_share"
    }

    /// 判定の入力。ビューにも `UsageStore` にも依存しない値だけで組む。
    public struct Input: Sendable {
        public var modelCosts: [String: Double] = [:]
        public var cursorTotal: Double = 0
        public var claudeTotal: Double = 0
        public var isDegraded = false

        public init(modelCosts: [String: Double] = [:], cursorTotal: Double = 0,
                    claudeTotal: Double = 0, isDegraded: Bool = false) {
            self.modelCosts = modelCosts
            self.cursorTotal = cursorTotal
            self.claudeTotal = claudeTotal
            self.isDegraded = isDegraded
        }
    }

    /// 出すべきヒント。並び順は呼び出し側（`UsageStore`）が severity で決めるので、
    /// 取得が劣化している回は 1 件も出さない。欠けた金額を根拠にした助言は誤りになる。
    /// 区別できない 0 からは何も言わない。
    public static func hints(for input: Input) -> [RetokReport.Advice] {
        guard !input.isDegraded else { return [] }
        guard !input.modelCosts.isEmpty || input.cursorTotal > 0 else { return [] }

        var hints: [RetokReport.Advice] = []
        if let hint = unpricedModelsHint(modelCosts: input.modelCosts) { hints.append(hint) }
        if let hint = dominantModelHint(modelCosts: input.modelCosts) { hints.append(hint) }
        if let hint = shareHint(cursorTotal: input.cursorTotal, claudeTotal: input.claudeTotal) {
            hints.append(hint)
        }
        return hints
    }


    /// 価格表に無かったモデル。金額が実際より小さく出ているので、他のヒントより先に伝える。
    public static func unpricedModelsHint(modelCosts: [String: Double]) -> RetokReport.Advice? {
        let unpriced = modelCosts.filter { $0.value <= 0 }.keys.sorted()
        guard !unpriced.isEmpty else { return nil }
        return RetokReport.Advice(
            severity: "high",
            key: Key.unpricedModels,
            title: "\(unpriced.count) 件のモデルが価格表に無く、コストが実際より小さく出ています",
            detail: "対象は \(unpriced.joined(separator: ", ")) です。"
                + "Tokfuel は Cursor 公式の価格表に無いモデルを、当て推量の単価ではなく $0 として"
                + "数えます。表示中の Cursor コストはこのぶんだけ下振れしているので、"
                + "予算の判断にはそのまま使わないでください。")
    }

    public static func dominantModelHint(modelCosts: [String: Double]) -> RetokReport.Advice? {
        let priced = modelCosts.filter { $0.value > 0 }
        let total = priced.values.reduce(0, +)
        guard total > 0, let top = priced.max(by: { $0.value < $1.value }) else { return nil }
        let share = top.value / total
        guard share >= dominantModelShare else { return nil }
        return RetokReport.Advice(
            severity: "info",
            key: Key.dominantModel,
            title: "\(top.key) が Cursor コストの \(percent(share)) を占めています",
            detail: "確認や小さな編集まで同じモデルで回すと、単価の差がそのまま金額の差になります。"
                + "Cursor のモデル選択で軽い作業を安いモデルに寄せると、この偏りぶんが下がります。")
    }

    public static func shareHint(cursorTotal: Double, claudeTotal: Double) -> RetokReport.Advice? {
        let total = cursorTotal + claudeTotal
        guard total > 0 else { return nil }
        let share = cursorTotal / total
        guard share > cursorShareOfTotal else { return nil }
        return RetokReport.Advice(
            severity: "info",
            key: Key.share,
            title: "期間コストの \(percent(share)) は Cursor です",
            detail: "残りのヒントは Claude Code のトランスクリプトから出ています。"
                + "合算のままだと Claude 側の節約策だけを見てしまうので、"
                + "設定の「コストのソース」を「並べて表示」か「Cursor のみ」にして、"
                + "どちらを削るのが効くかを先に確かめてください。")
    }

    public static func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }
}
