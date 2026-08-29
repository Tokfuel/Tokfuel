import CryptoKit
import Foundation
import TokfuelCore

/// 差し替えるための置き場 — 正しさの源泉はあくまで再解析側で、ここは表示のつなぎに徹する。
public struct ReportCache: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// （python3 が消えた等）で、何週間も前のデータを現行として出し続けないため。
    public static let maxAge: TimeInterval = 3 * 86_400

    public static let shared = ReportCache(
        directory: AppSupport.directory.appendingPathComponent("report-cache", isDirectory: true))

    private func fileURL(
        period: ReportPeriod, weekStart: WeekStart, days: Int,
        lang: String, projectsPath: String
    ) -> URL {
        let digest = SHA256.hash(data: Data(projectsPath.utf8))
            .prefix(4).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(
            "report-\(period.rawValue)-\(weekStart.rawValue)-\(days)d-\(lang)-\(digest).json")
    }

    public func load(
        period: ReportPeriod, weekStart: WeekStart, days: Int,
        lang: String, projectsPath: String
    ) -> RetokReport? {
        let url = fileURL(period: period, weekStart: weekStart, days: days,
                          lang: lang, projectsPath: projectsPath)
        guard let modified = (try? FileManager.default.attributesOfItem(atPath: url.path))?[
            .modificationDate] as? Date,
            Date().timeIntervalSince(modified) <= Self.maxAge,
            let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RetokReport.self, from: data)
    }

    /// 保存の失敗は握りつぶす — キャッシュが無い状態に戻るだけで、機能は損なわれない。
    public func save(
        _ report: RetokReport,
        period: ReportPeriod, weekStart: WeekStart, days: Int,
        lang: String, projectsPath: String
    ) {
        guard let data = try? JSONEncoder().encode(report) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(
            to: fileURL(period: period, weekStart: weekStart, days: days,
                        lang: lang, projectsPath: projectsPath),
            options: .atomic)
    }
}
