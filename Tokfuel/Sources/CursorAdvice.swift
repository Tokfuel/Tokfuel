import Foundation

/// Cursor のデータだけから「節約のヒント」を組み立てる。
///
/// retok は同梱の無改変ファイルなので手を入れない（AGENTS.md グラウンドルール 3）。
/// Cursor 由来のヒントはここで作り、retok の `advice` と同じ `RetokReport.Advice` の形に
/// 揃えて 1 つのセクションに並べる（合成と抑止は `UsageStore`、描画は `PopoverView`）。
///
/// 判定はすべて純粋関数で、入力は `UsageStore` が既に持っている期間内の数字だけ。
/// ネットワークもプロセス起動も増やさない。
enum CursorAdvice {
    /// ヒントの出どころとして UI に出すバッジの文字列。
    static let sourceLabel = "Cursor"

    /// 最上位モデルがこの割合「以上」を占めたら偏りとみなす。
    static let dominantModelShare = 0.60
    /// 期間合計に占める Cursor がこの割合を「超えた」ら Cursor 主体とみなす。
    static let cursorShareOfTotal = 0.50

    /// `RetokReport.Advice.key`。retok 側のキー（`adv_*`）と衝突しない接頭辞にする。
    enum Key {
        static let dominantModel = "cursor_dominant_model"
        static let unpricedModels = "cursor_unpriced_models"
        static let share = "cursor_share"
    }

    /// 判定の入力。ビューにも `UsageStore` にも依存しない値だけで組む。
    struct Input {
        /// 期間内の Cursor モデル別コスト (USD)。値が 0 のモデルは、`CursorPricing` が
        /// 価格を引けず $0 として計上したもの（当て推量の単価は使わない仕様）。
        var modelCosts: [String: Double] = [:]
        /// 期間内の Cursor 合計コスト (USD)。モデル別内訳が空でも日別からは出せるので別に受ける。
        var cursorTotal: Double = 0
        /// 期間内の Claude (retok) 合計コスト (USD)。
        var claudeTotal: Double = 0
        /// Cursor の取得が劣化していて、金額が実態より小さいと分かっているか。
        var isDegraded = false
    }

    /// 出すべきヒント。並び順は呼び出し側（`UsageStore`）が severity で決めるので、
    /// ここでは判定した順に返すだけ。
    ///
    /// 取得が劣化している回は 1 件も出さない。欠けた金額を根拠にした助言は誤りになる。
    /// データが 1 件も無い回も同じで、「本当に使っていない」のか「取れなかった」のかを
    /// 区別できない 0 からは何も言わない。
    static func hints(for input: Input) -> [RetokReport.Advice] {
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

    // MARK: - 個別の判定

    /// 価格表に無かったモデル。金額が実際より小さく出ているので、他のヒントより先に伝える。
    static func unpricedModelsHint(modelCosts: [String: Double]) -> RetokReport.Advice? {
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

    /// 1 つのモデルへの偏り。安いモデルへ寄せる余地があるかを見る。
    static func dominantModelHint(modelCosts: [String: Double]) -> RetokReport.Advice? {
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

    /// 期間合計に占める Cursor の割合。高いのに合算表示のままだと、Claude 側の対策だけを見てしまう。
    static func shareHint(cursorTotal: Double, claudeTotal: Double) -> RetokReport.Advice? {
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

    /// 0.738 → "74%"。retok の advice と同じく、割合は整数％で出す。
    static func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }
}
