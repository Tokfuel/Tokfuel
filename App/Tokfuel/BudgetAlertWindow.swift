import AppKit
import SwiftUI

/// 予算アラートのウィンドウ（TF #81）。1 枚だけ作って使い回す。
///
/// `NSAlert.runModal()` は使わない。モーダルループはアクセサリアプリのメインスレッドを
/// 占有し、閉じるまでメニューバーの更新まで止まってしまうため。代わりにフローティングの
/// パネルを自前で出し、全画面の Space で作業していても見えるようにする
/// （`.canJoinAllSpaces` + `.fullScreenAuxiliary`）。
///
/// パネル（`.nonactivatingPanel`）にしているのは、アクセサリアプリが他アプリのフォーカスを
/// 奪わずにボタンのクリックを受け取れるようにするため。前面化の合図は
/// `NSApp.requestUserAttention(.criticalRequest)` に任せる。
@MainActor
final class BudgetAlertWindow {
    static let shared = BudgetAlertWindow()

    /// 表示中の中身。レベルが上がったらウィンドウを増やさず、ここを差し替える。
    final class Model: ObservableObject {
        @Published var content: BudgetAlertContent
        /// ボタンの動作。ウィンドウを作り直さずに差し替えられるよう、モデル側に置く。
        var onClose: () -> Void = {}
        var onOpenSettings: () -> Void = {}
        init(content: BudgetAlertContent) { self.content = content }
    }

    private var window: NSWindow?
    private var model: Model?

    /// アラートを出す（すでに出ているときは中身だけ差し替える）。
    func show(_ content: BudgetAlertContent, onOpenSettings: @escaping () -> Void = {}) {
        let model = model ?? Model(content: content)
        model.content = content
        model.onClose = { [weak self] in self?.close() }
        model.onOpenSettings = { [weak self] in
            self?.close()
            onOpenSettings()
        }
        self.model = model

        let window = window ?? makeWindow(model: model)
        self.window = window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        // Dock アイコンを持たないアクセサリアプリなので、実効は通知音と前面化になる。
        NSApp.requestUserAttention(.criticalRequest)

        UsageEventLog.shared.log(.alertShown, meta: ["kind": "budget-\(content.kind.rawValue)"])
    }

    /// 閉じる（ウィンドウは破棄せず次回に使い回す）。
    func close() {
        window?.orderOut(nil)
    }

    private func makeWindow(model: Model) -> NSWindow {
        let hosting = NSHostingController(rootView: Host(model: model))
        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.titled, .closable, .fullSizeContentView, .nonactivatingPanel]
        panel.title = MenuBarReadout.windowTitle("Tokfuel 予算アラート")
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.center()
        return panel
    }

    /// モデルの変更をビューへ届けるだけの器。
    private struct Host: View {
        @ObservedObject var model: Model

        var body: some View {
            BudgetAlertView(content: model.content,
                            onClose: { model.onClose() },
                            onOpenSettings: { model.onOpenSettings() })
                .tint(.orange)   // App.swift と同じアクセント
        }
    }
}
