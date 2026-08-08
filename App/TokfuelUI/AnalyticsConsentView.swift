import SwiftUI
import TokfuelCore
import TokfuelSettings
import TokfuelStore
import TokfuelBudget
import TokfuelAnalytics
import TokfuelClaude
import TokfuelCursor

/// 初回 Analytics 同意ダイアログの中身（#22）。
/// ウィンドウの出し方は `AppDelegate` が持ち、ここは純粋な表示層。
/// ui-preview（`ScreenshotRenderer`）も同じビューを撮るので、文面を変えたら絵も追従する。
public struct AnalyticsConsentView: View {
    public var onAllow: () -> Void = {}
    public var onDeny: () -> Void = {}

    public init(onAllow: @escaping () -> Void = {}, onDeny: @escaping () -> Void = {}) {
        self.onAllow = onAllow
        self.onDeny = onDeny
    }

    public static let title = "利用状況の送信"
    public static let bodyText = """
    Tokfuel の改善のため、タブ表示や設定変更などアプリ自身の操作を匿名で送れます。
    プロンプト、コスト、ファイルパスなど Claude / Cursor 由来のデータは送りません。
    あとから設定の「プライバシー」で変更できます。
    """
    public static let allowTitle = "許可する"
    public static let denyTitle = "許可しない"

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(Self.title)
                        .font(.headline)
                    Text(Self.bodyText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                Spacer()
                Button(Self.denyTitle, action: onDeny)
                    .keyboardShortcut(.cancelAction)
                Button(Self.allowTitle, action: onAllow)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
