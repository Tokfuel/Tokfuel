import CoreGraphics

/// Layout and label rules for the popover’s model-cost rows (IT-F001).
enum ModelBreakdownLayout {
    /// Wider than the old 100pt fixed column so long Cursor IDs stay readable in one line.
    static let nameMinWidth: CGFloat = 168
    /// Keep the money column’s historical trailing width.
    static let moneyWidth: CGFloat = 64

    /// Show the raw model ID. Display-only shortening must not hide distinguishing suffixes.
    static func name(_ model: String) -> String { model }
}
