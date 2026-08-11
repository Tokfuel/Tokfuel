import Foundation
import Testing
@testable import TokfuelCore
@testable import TokfuelSettings
@testable import TokfuelClaude
@testable import TokfuelCursor
@testable import TokfuelCodex
@testable import TokfuelBudget
@testable import TokfuelAnalytics
@testable import TokfuelStore
@testable import TokfuelUI
@testable import Tokfuel

struct UpdateVersionTests {
    @Test func 新しいバージョンを検知する() {
        #expect(UpdateChecker.isNewer("v0.0.4", than: "0.0.3"))
    }

    @Test func 同じバージョンは新しくない() {
        #expect(!UpdateChecker.isNewer("v0.0.3", than: "0.0.3"))
    }

    @Test func 古いバージョンは新しくない() {
        #expect(!UpdateChecker.isNewer("v0.0.2", than: "0.0.3"))
    }

    @Test func 文字列ではなく数値で比較する() {
        #expect(UpdateChecker.isNewer("0.10.0", than: "0.9.9"))
    }

    @Test func 桁数が違っても比較できる() {
        #expect(UpdateChecker.isNewer("1.0", than: "0.9.9"))
        #expect(!UpdateChecker.isNewer("1.0", than: "1.0.0"))
        #expect(UpdateChecker.isNewer("1.0.0.1", than: "1.0.0"))
    }

    @Test func 解釈できないタグは提案しない() {
        #expect(!UpdateChecker.isNewer("beta", than: "0.0.3"))
        #expect(!UpdateChecker.isNewer("v1.0.0-rc1", than: "0.0.3"))
        #expect(!UpdateChecker.isNewer("", than: "0.0.3"))
        #expect(!UpdateChecker.isNewer("v1.0.0", than: "dev"))
    }
}

struct UpdateReleaseDecodeTests {
    @Test func GitHubのレスポンスを読める() throws {
        // /repos/{owner}/{repo}/releases/latest の実レスポンスから、使う項目だけを抜粋。
        let json = """
        {
          "tag_name": "v0.0.4",
          "html_url": "https://github.com/Tokfuel/Tokfuel/releases/tag/v0.0.4",
          "draft": false,
          "assets": [
            {
              "name": "Tokfuel-0.0.4.dmg",
              "content_type": "application/x-apple-diskimage",
              "size": 1065237,
              "browser_download_url": "https://github.com/Tokfuel/Tokfuel/releases/download/v0.0.4/Tokfuel-0.0.4.dmg"
            }
          ]
        }
        """
        let release = try JSONDecoder().decode(UpdateChecker.Release.self, from: Data(json.utf8))
        #expect(release.tagName == "v0.0.4")
        #expect(release.htmlURL == "https://github.com/Tokfuel/Tokfuel/releases/tag/v0.0.4")
        #expect(release.assets.first?.name == "Tokfuel-0.0.4.dmg")
        #expect(release.assets.first?.browserDownloadURL
                == "https://github.com/Tokfuel/Tokfuel/releases/download/v0.0.4/Tokfuel-0.0.4.dmg")
    }
}

/// アップデートボタン提示の判定（新しいか・抑制中か・使えるアセットがあるか）をまとめて確かめる。
struct UpdateEvaluateTests {
    private func release(tag: String,
                         assets: [String] = ["Tokfuel-9.9.9.dmg"]) -> UpdateChecker.Release {
        UpdateChecker.Release(
            tagName: tag,
            htmlURL: "https://github.com/Tokfuel/Tokfuel/releases/tag/\(tag)",
            assets: assets.map {
                .init(name: $0, browserDownloadURL: "https://example.com/\($0)")
            })
    }

    @Test func 新しいリリースを提示する() {
        let update = UpdateChecker.evaluate(release(tag: "v0.0.4"),
                                            current: "0.0.3", skipped: nil)
        #expect(update?.version == "0.0.4")
        #expect(update?.assetURL.lastPathComponent == "Tokfuel-9.9.9.dmg")
    }

    @Test func 追いついていれば畳む() {
        #expect(UpdateChecker.evaluate(release(tag: "v0.0.3"),
                                       current: "0.0.3", skipped: nil) == nil)
    }

    @Test func 後でを押した版は出さない() {
        #expect(UpdateChecker.evaluate(release(tag: "v0.0.4"),
                                       current: "0.0.3", skipped: "0.0.4") == nil)
    }

    @Test func 抑制した版より新しい版は再び提示する() {
        let update = UpdateChecker.evaluate(release(tag: "v0.0.5"),
                                            current: "0.0.3", skipped: "0.0.4")
        #expect(update?.version == "0.0.5")
    }

    @Test func 使えるアセットがなければ提示しない() {
        #expect(UpdateChecker.evaluate(release(tag: "v0.0.4", assets: ["notes.txt"]),
                                       current: "0.0.3", skipped: nil) == nil)
    }
}

struct UpdateAssetPickTests {
    private func asset(_ name: String) -> UpdateChecker.Release.Asset {
        UpdateChecker.Release.Asset(
            name: name,
            browserDownloadURL: "https://example.com/\(name)")
    }

    @Test func バージョン付きdmgをlatestより優先する() {
        let picked = UpdateChecker.pickAsset([asset("Tokfuel-latest.dmg"),
                                              asset("Tokfuel-0.0.4.dmg")])
        #expect(picked?.name == "Tokfuel-0.0.4.dmg")
    }

    @Test func dmgがlatestしかなければそれを使う() {
        let picked = UpdateChecker.pickAsset([asset("Tokfuel-latest.dmg")])
        #expect(picked?.name == "Tokfuel-latest.dmg")
    }

    @Test func dmgがなければzipに落ちる() {
        let picked = UpdateChecker.pickAsset([asset("Tokfuel-0.0.3.zip")])
        #expect(picked?.name == "Tokfuel-0.0.3.zip")
    }

    @Test func 使えるアセットがなければnil() {
        #expect(UpdateChecker.pickAsset([]) == nil)
        #expect(UpdateChecker.pickAsset([asset("checksums.txt")]) == nil)
    }
}

/// 実アーカイブ（temp dir 内で作った zip / dmg）からの展開。ユーザー状態には触れない。
struct UpdateExtractTests {
    /// Contents/MacOS だけ持つ最小の偽 .app を作る。
    private func makeFakeApp(in dir: URL) throws -> URL {
        let app = dir.appendingPathComponent("Fake.app", isDirectory: true)
        let macOS = app.appendingPathComponent("Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try Data("fake".utf8).write(to: macOS.appendingPathComponent("Fake"))
        return app
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokfuelUpdateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func zipからappを取り出せる() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let app = try makeFakeApp(in: dir)
        let archive = dir.appendingPathComponent("Fake-1.0.0.zip")
        try UpdateChecker.run("/usr/bin/ditto", "-ck", "--keepParent", app.path, archive.path)

        let workDir = dir.appendingPathComponent("work", isDirectory: true)
        let extracted = try UpdateChecker.extractApp(from: archive, into: workDir)
        #expect(extracted.lastPathComponent == "Fake.app")
        #expect(FileManager.default.fileExists(
            atPath: extracted.appendingPathComponent("Contents/MacOS/Fake").path))
    }

    @Test func dmgからappを取り出せる() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // release.sh と同じく、.app を置いたステージングフォルダから dmg を焼く。
        let staging = dir.appendingPathComponent("staging", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        _ = try makeFakeApp(in: staging)
        let archive = dir.appendingPathComponent("Fake-1.0.0.dmg")
        try UpdateChecker.run("/usr/bin/hdiutil", "create", "-volname", "FakeTest",
                "-srcfolder", staging.path, "-ov", "-format", "UDZO", archive.path)

        let workDir = dir.appendingPathComponent("work", isDirectory: true)
        let extracted = try UpdateChecker.extractApp(from: archive, into: workDir)
        #expect(extracted.lastPathComponent == "Fake.app")
        #expect(FileManager.default.fileExists(
            atPath: extracted.appendingPathComponent("Contents/MacOS/Fake").path))
        // detach 済み（マウントポイントに何も残っていない）ことも確かめる。
        let mount = workDir.appendingPathComponent("mount")
        #expect(!FileManager.default.fileExists(
            atPath: mount.appendingPathComponent("Fake.app").path))
    }

    @Test func appが入っていないアーカイブは失敗する() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let payload = dir.appendingPathComponent("payload", isDirectory: true)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try Data("no app here".utf8).write(to: payload.appendingPathComponent("readme.txt"))
        let archive = dir.appendingPathComponent("Fake-1.0.0.zip")
        try UpdateChecker.run("/usr/bin/ditto", "-ck", payload.path, archive.path)

        let workDir = dir.appendingPathComponent("work", isDirectory: true)
        #expect(throws: UpdateChecker.UpdateError.self) {
            try UpdateChecker.extractApp(from: archive, into: workDir)
        }
    }
}
