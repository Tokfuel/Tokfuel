import SwiftUI

/// アラートウィンドウに出す 1 件の中身。`BudgetMonitor` の判断結果をそのまま運ぶ。
/// 文面（`message`）は通知と共有するので、同じ出来事が経路によって違う言い方にならない。
struct BudgetAlertContent: Equatable {
    var kind: BudgetMonitor.Kind
    var level: BudgetLevel
    var spend: Double
    var limit: Double
    var message: BudgetMonitor.Message

    /// 「今日」か「今月」か。
    var periodLabel: String { kind.periodLabel }
    var isOver: Bool { level == .over }
    var percent: Int { BudgetMonitor.percent(spend: spend, limit: limit) }
    /// ゲージの塗りは 100% で頭打ちにする（超過分は数字とラベルが伝える）。
    var ratio: Double { limit > 0 ? min(spend / limit, 1) : 0 }
}

/// 予算のしきい値に達したことを知らせるアラートの中身（TF #81）。
/// ウィンドウの生成と使い回しは `BudgetAlertWindow` が持ち、ここは純粋な表示層。
struct BudgetAlertView: View {
    let content: BudgetAlertContent
    var onClose: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    /// 超過は赤、しきい値到達は橙。メニューバーアイコンの色分けと同じ約束。
    private var accent: Color { content.isOver ? .red : .orange }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            amounts
            buttons
        }
        .padding(20)
        .frame(width: 360)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: content.isOver
                  ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(content.message.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(content.periodLabel)の予算")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var amounts: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Money.format(content.spend))
                    .font(.system(size: 26, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                Text("/ \(Money.format(content.limit))")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(content.percent)%")
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }
            // ポップオーバーの予算ゲージと同じメーターを使う（見え方を揃える）。
            MeterBar(fraction: content.ratio, color: accent)
        }
    }

    private var buttons: some View {
        HStack {
            Spacer()
            Button("閉じる", action: onClose)
                .keyboardShortcut(.cancelAction)
            Button("予算設定を開く", action: onOpenSettings)
                .keyboardShortcut(.defaultAction)
        }
    }
}
