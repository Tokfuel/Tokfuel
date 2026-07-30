import AppKit
import Security

/// GitHub Releases から新バージョンを検知し、ユーザー操作でその場で差し替える（TF #29）。
/// アプリで 4 つ目の通信: 公開 Releases API への照会（起動時 + 24 時間ごと）と、
/// ユーザーが「アップデート」を押したときだけのリリースアセットのダウンロード。
/// どちらも使用状況データ・トランスクリプト・識別情報は一切乗せない。
///
/// バックグラウンドの確認失敗（オフライン・レート制限・パース失敗）はすべて静かに諦め、
/// 次回のチェックに委ねる。ユーザーが明示的に押したアップデートの失敗だけはバナーに出す。
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    struct AvailableUpdate: Equatable, Sendable {
        let version: String     // 先頭の "v" を落とした表示用バージョン
        let pageURL: URL        // リリースページ — その場差し替えできないときの導線
        let assetURL: URL
        let assetName: String   // 拡張子で dmg / zip を判別する
    }

    enum InstallPhase: Equatable {
        case idle
        case working
        case failed(String)
    }

    @Published private(set) var available: AvailableUpdate?
    @Published private(set) var phase: InstallPhase = .idle

    /// 「後で」を押した版。その版だけ次回起動まで抑制する（仕様どおり永続化しない）。
    private var skippedVersion: String?
    private var timer: Timer?

    private static let latestReleaseURL =
        URL(string: "https://api.github.com/repos/Tokfuel/Tokfuel/releases/latest")!

    /// 起動時に 1 回、以後 24 時間ごとに確認する。デーモンや launch agent は使わない。
    func startPeriodicChecks() {
        guard timer == nil else { return }
        Task { await self.checkForUpdate() }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in await UpdateChecker.shared.checkForUpdate() }
        }
    }

    func checkForUpdate() async {
        guard phase != .working else { return }

        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let release = try? JSONDecoder().decode(Release.self, from: data)
        else { return }

        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        guard Self.isNewer(release.tagName, than: current) else {
            available = nil   // 追いついた（外で更新した・リリースが取り下げられた）ら畳む
            return
        }
        let version = Self.dropLeadingV(release.tagName)
        guard version != skippedVersion,
              let asset = Self.pickAsset(release.assets),
              let assetURL = URL(string: asset.browserDownloadURL),
              let pageURL = URL(string: release.htmlURL)
        else { return }
        available = AvailableUpdate(version: version, pageURL: pageURL,
                                    assetURL: assetURL, assetName: asset.name)
    }

    /// 「後で」— 提示中の版を次回起動まで出さない。
    func skipOffered() {
        skippedVersion = available?.version
        available = nil
        phase = .idle
    }

    /// 「アップデート」— ダウンロード → 検証 → 差し替えヘルパー起動 → 自プロセス終了。
    /// その場差し替えできない環境（`swift run`・App Translocation・設置先が書き込み不可）
    /// では、代わりにリリースページを開く。
    func installOffered() {
        guard let update = available, phase != .working else { return }
        guard let destination = Self.installedAppURL() else {
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

    // MARK: - バージョン比較とアセット選択（純粋関数・テスト対象）

    /// GitHub Releases API のレスポンスのうち、使う項目だけを読む。
    struct Release: Decodable {
        struct Asset: Decodable, Equatable, Sendable {
            let name: String
            let browserDownloadURL: String

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let htmlURL: String
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case assets
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    /// セマンティックバージョン比較。先頭の `v` を許容し、`.` 区切りを数値で比べる
    /// （足りない桁は 0 扱い）。数値にできないタグは「新しくない」に倒して提案しない。
    nonisolated static func isNewer(_ remote: String, than current: String) -> Bool {
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
        let parts = dropLeadingV(tag.trimmingCharacters(in: .whitespaces))
            .split(separator: ".", omittingEmptySubsequences: false)
            .map { Int($0) }
        guard !parts.isEmpty, !parts.contains(nil) else { return nil }
        return parts.compactMap { $0 }
    }

    nonisolated private static func dropLeadingV(_ tag: String) -> String {
        tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
    }

    /// ダウンロードするアセット。バージョン付き `.dmg` を最優先し、固定名の
    /// `Tokfuel-latest.dmg`、旧形式の `.zip` の順にフォールバックする。
    nonisolated static func pickAsset(_ assets: [Release.Asset]) -> Release.Asset? {
        let dmgs = assets.filter { $0.name.hasSuffix(".dmg") }
        if let versioned = dmgs.first(where: { !$0.name.hasSuffix("-latest.dmg") }) {
            return versioned
        }
        return dmgs.first ?? assets.first { $0.name.hasSuffix(".zip") }
    }

    // MARK: - ダウンロードと差し替え

    enum UpdateError: LocalizedError {
        case downloadFailed
        case appMissing
        case wrongBundle
        case signatureInvalid
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .downloadFailed: return "ダウンロードに失敗しました"
            case .appMissing: return "ダウンロードしたファイルにアプリが見つかりません"
            case .wrongBundle: return "ダウンロードしたアプリを確認できません"
            case .signatureInvalid: return "ダウンロードしたアプリの署名を検証できません"
            case .commandFailed: return "アップデートの展開に失敗しました"
            }
        }
    }

    /// その場差し替えの対象となる、いまの .app の場所。差し替えできない実行形態なら nil。
    nonisolated private static func installedAppURL() -> URL? {
        let path = Bundle.main.bundlePath
        guard path.hasSuffix(".app"), !path.contains("/AppTranslocation/") else { return nil }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path)
        else { return nil }
        return url
    }

    /// アセットを一時ディレクトリへ落とし、展開・検証し、差し替えヘルパーを起動する。
    /// 成功したら呼び出し側がプロセスを終了する（差し替えはヘルパーが引き継ぐ）。
    nonisolated private static func downloadAndStageReplacement(
        _ update: AvailableUpdate, replacing destination: URL) async throws {
        guard let (downloaded, response) = try? await URLSession.shared.download(from: update.assetURL),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { throw UpdateError.downloadFailed }

        // ダウンロード直後の一時ファイルは寿命が保証されないので、まず自分の作業場所へ移す。
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokfuelUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        let archive = workDir.appendingPathComponent(update.assetName)
        try FileManager.default.moveItem(at: downloaded, to: archive)

        // hdiutil / ditto は待ち合わせがブロッキングなので、協調スレッドから逃がす。
        try await Task.detached(priority: .userInitiated) {
            let newApp = try extractApp(from: archive, into: workDir)
            try validate(appAt: newApp)
            try launchReplaceHelper(newApp: newApp, destination: destination)
        }.value
    }

    /// アーカイブ（dmg / zip）から .app を取り出し、作業ディレクトリ内の URL を返す。
    nonisolated static func extractApp(from archive: URL, into workDir: URL) throws -> URL {
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

    /// すり替え・破損を弾く: 自分と同じ bundle ID で、コード署名が完全であること。
    nonisolated private static func validate(appAt url: URL) throws {
        guard let bundleID = Bundle(url: url)?.bundleIdentifier,
              bundleID == Bundle.main.bundleIdentifier else { throw UpdateError.wrongBundle }

        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode,
              SecStaticCodeCheckValidity(
                  code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), nil) == errSecSuccess
        else { throw UpdateError.signatureInvalid }
    }

    /// 本体プロセスの終了を待って .app を差し替え、quarantine を外して再起動する
    /// 小さなシェルヘルパーを起動する（待たずに戻る）。
    nonisolated private static func launchReplaceHelper(newApp: URL, destination: URL) throws {
        let script = """
        #!/bin/bash
        # Tokfuel 自己アップデート: $1=待つ PID, $2=新しい .app, $3=差し替え先
        while /bin/kill -0 "$1" 2>/dev/null; do /bin/sleep 0.2; done
        /bin/rm -rf "$3"
        /usr/bin/ditto "$2" "$3"
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

    /// 外部コマンドを実行し、非 0 終了なら投げる。出力は使わないので捨てる。
    nonisolated private static func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.commandFailed(tool) }
    }
}
