import AppKit
import SwiftUI
import TokfuelCore
import TokfuelSettings
import TokfuelStore
import TokfuelBudget
import TokfuelAnalytics
import TokfuelClaude
import TokfuelCursor

@MainActor
public final class BudgetAlertWindow {
    public static let shared = BudgetAlertWindow()

    public final class Model: ObservableObject {
        @Published var content: BudgetAlertContent
        var onClose: () -> Void = {}
        var onOpenSettings: () -> Void = {}
        init(content: BudgetAlertContent) { self.content = content }
    }

    private var window: NSWindow?
    private var model: Model?

    public func show(_ content: BudgetAlertContent, onOpenSettings: @escaping () -> Void = {}) {
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

    public func close() {
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
