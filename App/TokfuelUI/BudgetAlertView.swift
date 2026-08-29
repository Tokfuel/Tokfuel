import SwiftUI
import TokfuelBudget
import TokfuelCore
import TokfuelSettings
import TokfuelStore
import TokfuelAnalytics
import TokfuelClaude
import TokfuelCursor

public struct BudgetAlertView: View {
    public let content: BudgetAlertContent
    public var onClose: () -> Void = {}
    public var onOpenSettings: () -> Void = {}

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
