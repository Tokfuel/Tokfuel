import ApplicationServices
import AppKit
import Foundation

/// Tokfuel コア 6 シナリオを AX で駆動するドライバ（Maestro / Appium なし）。
/// 使い方: TokfuelE2E --pid <TokfuelのPID> [--recording <path>] [--write-recording <path>]
@main
struct TokfuelE2EMain {
    static func main() {
        let args = CommandLine.arguments
        guard let pidFlag = args.firstIndex(of: "--pid"),
              pidFlag + 1 < args.count,
              let pid = pid_t(args[pidFlag + 1]) else {
            fputs("usage: TokfuelE2E --pid <tokfuel-pid> [--recording path] [--write-recording path]\n", stderr)
            exit(2)
        }

        guard AXIsProcessTrusted() else {
            fputs("Accessibility permission is required for TokfuelE2E\n", stderr)
            exit(3)
        }

        let recordingPath = value(after: "--recording", in: args)
        let writePath = value(after: "--write-recording", in: args)
            ?? E2ERecording.localCachePath

        do {
            let driver = try AXDriver(pid: pid, recordingPath: recordingPath)
            try driver.runCore6()
            try driver.persistRecording(to: writePath)
            // 明示時のみリポジトリ正本を上書き（普段は .build 側のキャッシュを更新）。
            if ProcessInfo.processInfo.environment["TOKFUEL_E2E_UPDATE_REPO_RECORDING"] == "1",
               writePath != E2ERecording.defaultPath {
                try driver.persistRecording(to: E2ERecording.defaultPath)
            }
            print("TokfuelE2E core6 OK")
            exit(0)
        } catch {
            fputs("TokfuelE2E failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }
}

enum E2EError: Error, CustomStringConvertible {
    case notFound(String)
    case assertFailed(String)
    case timedOut(String)

    var description: String {
        switch self {
        case .notFound(let s): return "not found: \(s)"
        case .assertFailed(let s): return "assert failed: \(s)"
        case .timedOut(let s): return "timed out: \(s)"
        }
    }
}

final class AXDriver {
    private let app: AXUIElement
    private let pid: pid_t
    private let recording: E2ERecording?
    private let builder = E2ERecordingBuilder()
    private let pollInterval: TimeInterval

    init(pid: pid_t, recordingPath: String?) throws {
        self.pid = pid
        self.app = AXUIElementCreateApplication(pid)
        self.recording = E2ERecording.load(from: recordingPath)
        self.pollInterval = recording?.pollIntervalSeconds ?? 0.15
        // Warm up the tree.
        _ = copyAttribute(app, kAXRoleAttribute as String)
    }

    func runCore6() throws {
        try runScenario("MenuBar-01-open-home", scenarioMenuBar01OpenHome)
        try runScenario("Cost-03-model-list", scenarioCost03ModelList)
        try runScenario("Cost-01-chart-style", scenarioCost01ChartStyle)
        try runScenario("Cost-02-period-switch", scenarioCost02PeriodSwitch)
        try runScenario("Settings-01-open", scenarioSettings01Open)
        try runScenario("Settings-02-reflect", scenarioSettings02Reflect)
    }

    func persistRecording(to path: String) throws {
        let required = recording?.requiredIdentifiers ?? [
            "tokfuel.home",
            "tokfuel.hero.today",
            "tokfuel.section.trend",
            "tokfuel.section.models",
            "tokfuel.model-list",
            "tokfuel.chart.style",
            "tokfuel.chart.period",
            "tokfuel.menu.more",
            "tokfuel.settings"
        ]
        let built = builder.build(requiredIdentifiers: required, previous: recording)
        try built.write(to: path)
        print("E2E recording written: \(path)")
    }

    private func runScenario(_ id: String, _ body: () throws -> Void) throws {
        print("→ \(id)")
        builder.begin(id)
        do {
            try body()
            builder.endCurrent()
        } catch {
            builder.endCurrent()
            if let recording {
                fputs(
                    "baseline requiredIdentifiers: \(recording.requiredIdentifiers.joined(separator: ", "))\n",
                    stderr
                )
            }
            throw error
        }
    }

    private func timeout(_ cold: TimeInterval) -> TimeInterval {
        recording?.scaledTimeout(cold) ?? cold
    }

    // MARK: - Scenarios

    private func scenarioMenuBar01OpenHome() throws {
        try clickStatusItem()
        let home = try waitForIdentifier("tokfuel.home", under: app, timeout: timeout(8))
        _ = try waitForIdentifier("tokfuel.hero.today", under: home, timeout: timeout(5))
        guard findByIdentifier("tokfuel.section.trend", under: home) != nil
                || findByTitle("推移", under: home) != nil
                || findByValue("推移", under: home) != nil else {
            throw E2EError.assertFailed("推移 section missing")
        }
        builder.sawIdentifier("tokfuel.section.trend")
        guard findByIdentifier("tokfuel.section.models", under: home) != nil
                || findByIdentifier("tokfuel.model-list", under: home) != nil
                || findByTitle("モデル別", under: home) != nil
                || findByValue("モデル別", under: home) != nil else {
            throw E2EError.assertFailed("モデル別 section missing")
        }
        builder.sawIdentifier("tokfuel.section.models")
    }

    private func scenarioCost03ModelList() throws {
        let home = try requireIdentifier("tokfuel.home")
        let list = try waitForIdentifier("tokfuel.model-list", under: home, timeout: timeout(5))
        let rows = findAllByIdentifier("tokfuel.model-list.row", under: list)
        guard !rows.isEmpty else {
            throw E2EError.assertFailed("expected at least one model row")
        }
    }

    private func scenarioCost01ChartStyle() throws {
        let home = try requireIdentifier("tokfuel.home")
        let style = try waitForIdentifier("tokfuel.chart.style", under: home, timeout: timeout(5))
        // Segmented control: click the "累積" radio/button child.
        if let cumulative = findByTitle("累積", under: style) ?? findByLabel("累積", under: style) {
            try press(cumulative)
        } else {
            // Fallback: click the last button-like child.
            let buttons = children(of: style).filter {
                role($0) == "AXRadioButton" || role($0) == "AXButton" || role($0) == "AXCheckBox"
            }
            guard let last = buttons.last else {
                throw E2EError.notFound("chart style segments")
            }
            try press(last)
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        // Switch back to 日別 to leave a stable state.
        if let daily = findByTitle("日別", under: style) ?? findByLabel("日別", under: style) {
            try press(daily)
        } else {
            let buttons = children(of: style).filter {
                role($0) == "AXRadioButton" || role($0) == "AXButton" || role($0) == "AXCheckBox"
            }
            if let first = buttons.first { try press(first) }
        }
    }

    private func scenarioCost02PeriodSwitch() throws {
        let home = try requireIdentifier("tokfuel.home")
        let period = try waitForIdentifier("tokfuel.chart.period", under: home, timeout: timeout(5))
        let month = findByIdentifier("tokfuel.period.thisMonth", under: period)
            ?? findByTitle("今月", under: period)
            ?? findByValue("今月", under: period)
            ?? findByLabel("今月", under: period)
            ?? segmentChildren(of: period).dropFirst(2).first
        guard let month else { throw E2EError.notFound("period 今月") }
        try press(month)
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        // Selected / value should mention 今月 when possible; at least ensure control still exists.
        _ = try requireIdentifier("tokfuel.chart.period", under: home)
        let today = findByIdentifier("tokfuel.period.today", under: period)
            ?? findByTitle("今日", under: period)
            ?? findByValue("今日", under: period)
            ?? segmentChildren(of: period).first
        if let today { try press(today) }
    }

    private func scenarioSettings01Open() throws {
        let home = try requireIdentifier("tokfuel.home")
        let more = try waitForIdentifier("tokfuel.menu.more", under: home, timeout: timeout(5))
        try press(more)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        // Menu items live under the app or the menu extras; search broadly.
        guard let settingsItem = waitForTitle("設定", timeout: timeout(5)) else {
            throw E2EError.notFound("menu item 設定")
        }
        try press(settingsItem)
        do {
            _ = try waitForIdentifier("tokfuel.settings", under: app, timeout: timeout(8))
        } catch {
            _ = try waitForWindowTitle("Tokfuel 設定", timeout: timeout(8))
        }
    }

    private func scenarioSettings02Reflect() throws {
        let settings: AXUIElement
        if let rooted = try? waitForIdentifier("tokfuel.settings", under: app, timeout: timeout(5)) {
            settings = rooted
        } else {
            settings = try waitForWindowTitle("Tokfuel 設定", timeout: timeout(5))
        }
        // Currency → ¥ 円
        if let currency = findByIdentifier("tokfuel.settings.currency", under: settings) {
            if let yen = findByTitle("¥ 円", under: currency) ?? findByTitle("円", under: currency) {
                try press(yen)
            } else {
                let segments = children(of: currency).filter {
                    role($0) == "AXRadioButton" || role($0) == "AXButton"
                }
                if let last = segments.last { try press(last) }
            }
        }

        // Cost source → Claude のみ（stable single-source label）
        if let source = findByIdentifier("tokfuel.settings.cost-source", under: settings),
           let claudeOnly = findByTitle("Claude のみ", under: source) {
            try press(claudeOnly)
        }

        // Menu bar metric → 今月
        if let metric = findByIdentifier("tokfuel.settings.menu-bar-metric", under: settings),
           let month = findByTitle("今月", under: metric) {
            try press(month)
        }

        RunLoop.current.run(until: Date().addingTimeInterval(0.6))

        // Re-open home and observe yen formatting or Claude-only caption absence of side-by-side.
        try clickStatusItem()
        let home = try waitForIdentifier("tokfuel.home", under: app, timeout: timeout(8))
        // After currency switch, money strings typically contain "¥" or fullwidth yen.
        let treeText = collectTitles(under: home).joined(separator: " ")
        let looksJPY = treeText.contains("¥") || treeText.contains("円")
        guard looksJPY else {
            throw E2EError.assertFailed("expected JPY formatting after currency switch; saw: \(treeText.prefix(200))")
        }
    }

    // MARK: - Status item

    private func clickStatusItem() throws {
        // System Events 経由が NSStatusItem の target/action を最も確実に発火させる。
        // AXPress は成功しても action が走らないことがあり、CGEvent はマルチディスプレイで外れやすい。
        if clickStatusItemViaSystemEvents() {
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
            return
        }
        guard let item = findStatusItem() else {
            throw E2EError.notFound("tokfuel.status-item")
        }
        try click(item)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    }

    private func clickStatusItemViaSystemEvents() -> Bool {
        let script = """
        tell application "System Events"
          tell (first process whose unix id is \(pid))
            if (count of menu bars) < 2 then return false
            click menu bar item 1 of menu bar 2
            return true
          end tell
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return false }
        let result = appleScript.executeAndReturnError(&error)
        if let error {
            fputs("System Events click warning: \(error)\n", stderr)
            return false
        }
        return result.booleanValue
    }

    private func findStatusItem() -> AXUIElement? {
        // Prefer the extras menu bar. Identifier is often stripped on NSStatusItem;
        // match role + description/title instead. Never match the app's "Tokfuel" menu.
        let roots: [AXUIElement] = {
            var list: [AXUIElement] = []
            if let extras = copyElement(app, kAXExtrasMenuBarAttribute as String) {
                list.append(extras)
            }
            // App tree also mirrors the extras bar as a second AXMenuBar.
            list.append(app)
            return list
        }()

        for root in roots {
            if let byId = findByIdentifier("tokfuel.status-item", under: root),
               hasUsableFrame(byId) {
                return byId
            }
            let items = findAll(under: root) { el in
                role(el) == "AXMenuBarItem" && hasUsableFrame(el) && looksLikeStatusItem(el)
            }
            if let hit = items.first { return hit }
        }
        return nil
    }

    private func looksLikeStatusItem(_ el: AXUIElement) -> Bool {
        let t = title(el) ?? ""
        let d = description(el) ?? ""
        if d.contains("Tokfuel") || d.contains("推定コスト") || d.contains("estimated") { return true }
        if t.contains("$") || t.contains("¥") || t.contains("%") { return true }
        if t.contains("Claude") || t.contains("Cursor") { return true }
        return false
    }

    private func hasUsableFrame(_ el: AXUIElement) -> Bool {
        guard let f = frame(of: el) else { return false }
        return f.width > 1 && f.height > 1
    }

    // MARK: - AX primitives

    private func requireIdentifier(_ id: String, under root: AXUIElement? = nil) throws -> AXUIElement {
        if let el = findByIdentifier(id, under: root) {
            builder.sawIdentifier(id)
            return el
        }
        throw E2EError.notFound(uiDriftHint(id))
    }

    private func waitForIdentifier(
        _ id: String,
        under root: AXUIElement? = nil,
        timeout: TimeInterval
    ) throws -> AXUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let el = findByIdentifier(id, under: root ?? app) {
                builder.sawIdentifier(id)
                return el
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        throw E2EError.timedOut(uiDriftHint(id))
    }

    private func waitForTitle(_ title: String, timeout: TimeInterval) -> AXUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let el = findByTitle(title) { return el }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        return nil
    }

    private func waitForWindowTitle(_ title: String, timeout: TimeInterval) throws -> AXUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let windows = copyArray(app, kAXWindowsAttribute as String) {
                for window in windows {
                    if self.title(window) == title { return window }
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        throw E2EError.timedOut("window \(title)")
    }

    /// UI 改名などで identifier が消えたときに、baseline との差分がログに残るようにする。
    private func uiDriftHint(_ id: String) -> String {
        if let recording, recording.requiredIdentifiers.contains(id) {
            return "\(id) (present in last successful recording; UI may have changed)"
        }
        return id
    }

    private func findByIdentifier(_ id: String, under root: AXUIElement? = nil) -> AXUIElement? {
        findAll(under: root ?? app) { identifier($0) == id }.first
    }

    private func findAllByIdentifier(_ id: String, under root: AXUIElement) -> [AXUIElement] {
        findAll(under: root) { identifier($0) == id }
    }

    private func findByTitle(_ wanted: String, under root: AXUIElement? = nil) -> AXUIElement? {
        findAll(under: root ?? app) { title($0) == wanted }.first
    }

    private func findByLabel(_ wanted: String, under root: AXUIElement) -> AXUIElement? {
        findAll(under: root) { description($0) == wanted || title($0) == wanted }.first
    }

    private func findByValue(_ wanted: String, under root: AXUIElement) -> AXUIElement? {
        findAll(under: root) { value($0) == wanted }.first
    }

    private func segmentChildren(of el: AXUIElement) -> [AXUIElement] {
        children(of: el).filter {
            let r = role($0)
            return r == "AXRadioButton" || r == "AXButton" || r == "AXCheckBox"
        }
    }

    private func value(_ el: AXUIElement) -> String? {
        copyString(el, kAXValueAttribute as String)
    }

    private func findAll(under root: AXUIElement, where predicate: (AXUIElement) -> Bool) -> [AXUIElement] {
        var result: [AXUIElement] = []
        func walk(_ el: AXUIElement, depth: Int) {
            guard depth < 30 else { return }
            if predicate(el) { result.append(el) }
            for child in children(of: el) {
                walk(child, depth: depth + 1)
            }
        }
        walk(root, depth: 0)
        return result
    }

    private func collectTitles(under root: AXUIElement) -> [String] {
        findAll(under: root) { title($0) != nil || value($0) != nil }
            .compactMap { title($0) ?? value($0) }
    }

    private func children(of el: AXUIElement) -> [AXUIElement] {
        copyArray(el, kAXChildrenAttribute as String) ?? []
    }

    private func press(_ el: AXUIElement) throws {
        let err = AXUIElementPerformAction(el, kAXPressAction as CFString)
        if err == .success { return }
        // Status items and some SwiftUI controls reject AXPress; fall back to a
        // synthesized mouse click at the element's frame.
        do {
            try click(el)
        } catch {
            throw E2EError.assertFailed("AXPress failed (\(err.rawValue)); click fallback: \(error)")
        }
    }

    private func click(_ el: AXUIElement) throws {
        guard let frame = frame(of: el), frame.width > 0, frame.height > 0 else {
            throw E2EError.assertFailed("no AX frame for click")
        }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        try postClick(at: point)
    }

    private func frame(of el: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func postClick(at axPoint: CGPoint) throws {
        // AX positions use a top-left origin on the primary display. CGEvent uses
        // the same global top-left origin on modern macOS (Quartz), so pass through.
        let cgPoint = axPoint
        let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                           mouseCursorPosition: cgPoint, mouseButton: .left)
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                           mouseCursorPosition: cgPoint, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                         mouseCursorPosition: cgPoint, mouseButton: .left)
        guard let move, let down, let up else {
            throw E2EError.assertFailed("CGEvent creation failed")
        }
        move.post(tap: .cghidEventTap)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        down.post(tap: .cghidEventTap)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        up.post(tap: .cghidEventTap)
    }

    private func identifier(_ el: AXUIElement) -> String? {
        copyString(el, kAXIdentifierAttribute as String)
    }

    private func title(_ el: AXUIElement) -> String? {
        copyString(el, kAXTitleAttribute as String)
    }

    private func description(_ el: AXUIElement) -> String? {
        copyString(el, kAXDescriptionAttribute as String)
    }

    private func role(_ el: AXUIElement) -> String? {
        copyString(el, kAXRoleAttribute as String)
    }

    private func copyString(_ el: AXUIElement, _ attr: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success,
              let value else { return nil }
        return value as? String
    }

    private func copyElement(_ el: AXUIElement, _ attr: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success,
              let value else { return nil }
        return (value as! AXUIElement)
    }

    private func copyArray(_ el: AXUIElement, _ attr: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success,
              let array = value as? [AXUIElement] else { return nil }
        return array
    }

    private func copyAttribute(_ el: AXUIElement, _ attr: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success else {
            return nil
        }
        return value
    }
}
