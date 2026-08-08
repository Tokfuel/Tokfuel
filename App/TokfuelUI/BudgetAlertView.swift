import SwiftUI
import TokfuelBudget
import TokfuelCore
import TokfuelSettings
import TokfuelStore
import TokfuelAnalytics
import TokfuelClaude
import TokfuelCursor

/// 予算のしきい値に達したことを知らせるアラートの中身（TF #81）。
/// ウィンドウの生成と使い回しは `BudgetAlertWindow` が持ち、ここは純粋な表示層。
public struct BudgetAlertView: View {
    public let content: BudgetAlertContent
    public var onClose: () -> Void = {}
    public var onOpenSettings: () -> Void = {}

    /// 超過は赤、しきい値到達は橙。メニューバーアイコンの色分けと同じ約束。
    private var accent: Color { content.isOver ? .red : .orange }

    public var body: some View {
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
