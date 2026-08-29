import AppKit
import Security
import TokfuelCore
import TokfuelSettings
import TokfuelStore
import TokfuelBudget
import TokfuelAnalytics
import TokfuelClaude
import TokfuelCursor

@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()

    public struct AvailableUpdate: Sendable {
        let version: String     // 先頭の "v" を落とした表示用バージョン
        let pageURL: URL        // リリースページ — その場差し替えできないときの導線
        let assetURL: URL
    }

    public enum InstallPhase: Equatable {
        case idle
        case working
        case failed(String)
    }

    @Published private(set) var available: AvailableUpdate?
    @Published private(set) var phase: InstallPhase = .idle

    private(set) var installTarget: URL?
    public var installsInPlace: Bool { installTarget != nil }

    /// 「後で」は永続化しない（その版だけ次回起動まで抑制）。
    private var skippedVersion: String?
    private var timer: Timer?

    private static let latestReleaseURL =
        URL(string: "https://api.github.com/repos/Tokfuel/Tokfuel/releases/latest")!

    private init() {
        installTarget = Self.installedAppURL()
    }

    /// debug バイナリは `.app` ではないので実判定に任せると「リリースページを開く」側になり、
    /// 大多数のユーザーが見る「アップデート」ボタンを ui-preview で確かめられない。
    public static func preview(version: String) -> UpdateChecker {
        let checker = UpdateChecker()
        checker.installTarget = URL(fileURLWithPath: "/Applications/Tokfuel.app")
        checker.available = AvailableUpdate(
            version: version,
            pageURL: URL(string: "https://github.com/Tokfuel/Tokfuel/releases/tag/v\(version)")!,
            assetURL: URL(string:
                "https://github.com/Tokfuel/Tokfuel/releases/download/v\(version)/Tokfuel-\(version).dmg")!)
        return checker
    }

    public func startPeriodicChecks() {
        guard timer == nil else { return }
        Task { await self.checkForUpdate() }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in await UpdateChecker.shared.checkForUpdate() }
        }
        timer?.tolerance = 60 * 60   // 定刻性は不要 — システムに起床をまとめさせる
    }

    public func checkForUpdate() async {
        guard phase != .working else { return }

        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let release = try? JSONDecoder().decode(Release.self, from: data),
              phase != .working   // 待っている間にアップデートが始まっていたら結果を捨てる
        else { return }

        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let offer = Self.evaluate(release, current: current, skipped: skippedVersion)
        if offer?.version != available?.version {
            phase = .idle   // 前の版へのインストール失敗表示を、別の版の提示に持ち越さない
        }
        available = offer
    }

    public func skipOffered() {
        skippedVersion = available?.version
        available = nil
        phase = .idle
    }

    public func installOffered() {
        guard let update = available, phase != .working else { return }
        guard let destination = installTarget else {
            NSWorkspace.shared.open(update.pageURL)
            return
        }
        phase = .working
        Task {
            do {
                try await Self.downloadAndStageReplacement(update, replacing: destination)
                NSApp.terminate(nil)   // ここから先はヘルパーが差し替えと再起動を担う
            } catch {
                phase = .failed((error as? UpdateError)?.errorDescription
                                ?? "アップデートに失敗しました")
            }
        }
    }


    public struct Release: Decodable {
        public struct Asset: Decodable {
            let name: String
            let browserDownloadURL: String

            public enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let htmlURL: String
        let assets: [Asset]

        public enum CodingKeys: String, CodingKey {
            case assets
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    public nonisolated static func evaluate(_ release: Release, current: String,
                                     skipped: String?) -> AvailableUpdate? {
        guard isNewer(release.tagName, than: current) else { return nil }
        let version = dropLeadingV(release.tagName)
        guard version != skipped,
              let asset = pickAsset(release.assets),
              let assetURL = URL(string: asset.browserDownloadURL),
              let pageURL = URL(string: release.htmlURL)
        else { return nil }
        return AvailableUpdate(version: version, pageURL: pageURL, assetURL: assetURL)
    }

    /// （足りない桁は 0 扱い）。数値にできないタグは「新しくない」に倒して提案しない。
    public nonisolated static func isNewer(_ remote: String, than current: String) -> Bool {
        guard let remoteParts = versionComponents(remote),
              let currentParts = versionComponents(current) else { return false }
        for i in 0..<max(remoteParts.count, currentParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r != c { return r > c }
        }
        return false
    }

    nonisolated private static func versionComponents(_ tag: String) -> [Int]? {
        let raw = dropLeadingV(tag.trimmingCharacters(in: .whitespaces))
            .split(separator: ".", omittingEmptySubsequences: false)
        let parts = raw.compactMap { Int($0) }
        return parts.count == raw.count ? parts : nil
    }

    nonisolated private static func dropLeadingV(_ tag: String) -> String {
        tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
    }

    public nonisolated static func pickAsset(_ assets: [Release.Asset]) -> Release.Asset? {
        let dmgs = assets.filter { $0.name.hasSuffix(".dmg") }
        if let versioned = dmgs.first(where: { !$0.name.hasSuffix("-latest.dmg") }) {
            return versioned
        }
        return dmgs.first ?? assets.first { $0.name.hasSuffix(".zip") }
    }


    public enum UpdateError: LocalizedError {
        case downloadFailed
        case appMissing
        case wrongBundle
        case signatureInvalid
        case commandFailed

        public var errorDescription: String? {
            switch self {
            case .downloadFailed: return "ダウンロードに失敗しました"
            case .appMissing: return "ダウンロードしたファイルにアプリが見つかりません"
            case .wrongBundle: return "ダウンロードしたアプリを確認できません"
            case .signatureInvalid: return "ダウンロードしたアプリの署名を検証できません"
            case .commandFailed: return "アップデートの展開に失敗しました"
            }
        }
    }

    nonisolated private static func installedAppURL() -> URL? {
        let path = Bundle.main.bundlePath
        guard path.hasSuffix(".app"), !path.contains("/AppTranslocation/") else { return nil }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path)
        else { return nil }
        return url
    }

    /// hdiutil / ditto の待ち合わせが main actor を塞ぐと UI が止まるので nonisolated にしている。
    nonisolated private static func downloadAndStageReplacement(
        _ update: AvailableUpdate, replacing destination: URL) async throws {
        guard let (downloaded, response) = try? await URLSession.shared.download(from: update.assetURL),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { throw UpdateError.downloadFailed }

        // ダウンロード直後の一時ファイルは寿命が保証されないので、まず自分の作業場所へ移す。
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokfuelUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        do {
            let archive = workDir.appendingPathComponent(update.assetURL.lastPathComponent)
            try FileManager.default.moveItem(at: downloaded, to: archive)
            let newApp = try extractApp(from: archive, into: workDir)
            try validate(appAt: newApp, expecting: update.version)
            try launchReplaceHelper(newApp: newApp, destination: destination)
        } catch {
            try? FileManager.default.removeItem(at: workDir)
            throw error
        }
    }

    public nonisolated static func extractApp(from archive: URL, into workDir: URL) throws -> URL {
        let extracted = workDir.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)

        if archive.pathExtension == "dmg" {
            let mountPoint = workDir.appendingPathComponent("mount", isDirectory: true)
            try run("/usr/bin/hdiutil", "attach", archive.path,
                    "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mountPoint.path)
            defer { try? run("/usr/bin/hdiutil", "detach", mountPoint.path, "-force") }
            guard let app = findApp(in: mountPoint) else { throw UpdateError.appMissing }
            // ボリュームは detach で消えるので、検証前にコピーで手元へ残す。
            let copied = extracted.appendingPathComponent(app.lastPathComponent)
            try run("/usr/bin/ditto", app.path, copied.path)
            return copied
        } else {
            try run("/usr/bin/ditto", "-xk", archive.path, extracted.path)
            guard let app = findApp(in: extracted) else { throw UpdateError.appMissing }
            return app
        }
    }

    nonisolated private static func findApp(in directory: URL) -> URL? {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        return entries.first { $0.pathExtension == "app" }
    }

    /// bundle ID・版・署名を検証し、すり替え・破損・中身違いを弾く。
    nonisolated private static func validate(appAt url: URL, expecting version: String) throws {
        guard let bundle = Bundle(url: url),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.infoDictionary?["CFBundleShortVersionString"] as? String == version
        else { throw UpdateError.wrongBundle }

        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode,
              SecStaticCodeCheckValidity(
                  code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), nil) == errSecSuccess
        else { throw UpdateError.signatureInvalid }
    }

    nonisolated private static func launchReplaceHelper(newApp: URL, destination: URL) throws {
        let script = """
        #!/bin/bash
        # Tokfuel 自己アップデート: $1=待つ PID, $2=新しい .app, $3=差し替え先
        # 旧アプリを消すのは、新アプリのコピーが差し替え先ボリュームに置けてから。
        # 途中で失敗しても「アプリが消えただけ」の状態を作らない。
        while /bin/kill -0 "$1" 2>/dev/null; do /bin/sleep 0.2; done
        /bin/rm -rf "$3.new"
        /usr/bin/ditto "$2" "$3.new" || exit 1
        /bin/rm -rf "$3" && /bin/mv "$3.new" "$3" || exit 1
        /usr/bin/xattr -dr com.apple.quarantine "$3" 2>/dev/null
        /usr/bin/open "$3"
        """
        let scriptURL = newApp.deletingLastPathComponent().appendingPathComponent("replace.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/bash")
        helper.arguments = [scriptURL.path,
                            String(ProcessInfo.processInfo.processIdentifier),
                            newApp.path, destination.path]
        try helper.run()
    }

    public nonisolated static func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice   // SLA 付き dmg の入力待ちを即失敗に
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.commandFailed }
    }
}
