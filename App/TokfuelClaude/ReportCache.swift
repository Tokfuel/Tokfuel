import CryptoKit
import Foundation
import TokfuelCore

/// 直近の retok レポートを期間（日数）別にディスクへ残す小さなキャッシュ（TF #53）。
/// 起動直後・期間切り替えの瞬間に「前回の絵」を即座に出し、裏の再解析（数秒）が終わり次第
/// 差し替えるための置き場 — 正しさの源泉はあくまで再解析側で、ここは表示のつなぎに徹する。
public struct ReportCache: Sendable {
    /// 保存先ディレクトリ。テストは一時ディレクトリを注入する
    /// （実ユーザーの `~/Library/Application Support/Tokfuel` に触れないため）。
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// これより古いキャッシュは無かったことにする。
    /// （python3 が消えた等）で、何週間も前のデータを現行として出し続けないため。
    public static let maxAge: TimeInterval = 3 * 86_400

    public static let shared = ReportCache(
        directory: AppSupport.directory.appendingPathComponent("report-cache", isDirectory: true))

    /// キーは retok の実行を左右する入力（暦期間・週始まり・経過日数・言語・走査ディレクトリ）
    /// すべてから組む。どれか 1 つでも欠くと、その設定を切り替えた直後に別条件のレポートを
    /// 再生してしまう。
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
