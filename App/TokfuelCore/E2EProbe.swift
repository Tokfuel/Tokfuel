import Foundation

/// AX E2E 用の観測プローブ。Notification Center / ツールチップなど AX が脆い面を、
/// アプリ内の固定 identifier で同等観測できるようにする。
public enum E2EProbe {
    nonisolated(unsafe) public static var lastNotificationTitle: String?
    nonisolated(unsafe) public static var lastNotificationBody: String?
    nonisolated(unsafe) public static var lastTooltip: String?

    public static func recordNotification(title: String, body: String) {
        lastNotificationTitle = title
        lastNotificationBody = body
    }

    public static func recordTooltip(_ text: String) {
        lastTooltip = text
    }

    public static func reset() {
        lastNotificationTitle = nil
        lastNotificationBody = nil
        lastTooltip = nil
    }
}
