import SwiftUI
import AppKit

/// Colori semantici di sistema, per seguire l'aspetto e l'accento di macOS.
enum Palette {
    static let window = Color(nsColor: .windowBackgroundColor)
    static let chrome = Color(nsColor: .windowBackgroundColor)
    static let panel = Color(nsColor: .textBackgroundColor)
    static let column = Color(nsColor: .textBackgroundColor)
    static let columnAlt = Color(nsColor: .textBackgroundColor)
    static let rowHover = Color(nsColor: .quaternaryLabelColor).opacity(0.10)
    static let rowAlternate = Color(nsColor: NSColor.alternatingContentBackgroundColors.count > 1
        ? NSColor.alternatingContentBackgroundColors[1]
        : NSColor.controlBackgroundColor)
    static let selection = Color(nsColor: .selectedContentBackgroundColor)
    static let selectionInactive = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    static let selectedText = Color(nsColor: .alternateSelectedControlTextColor)
    static let selectedTextSecondary = Color(nsColor: .alternateSelectedControlTextColor).opacity(0.72)
    static let border = Color(nsColor: .separatorColor)
    static let borderStrong = Color(nsColor: .gridColor)
    static let text = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    static let danger = Color(nsColor: .systemRed)
    static let preview = Color(nsColor: .underPageBackgroundColor)
}

/// Colori dei tag Finder.
enum FinderTagColor {
    static func color(for name: String) -> Color? {
        let n = name.lowercased()
        if n.contains("red") || n.contains("rosso") { return .red }
        if n.contains("orange") || n.contains("arancione") { return .orange }
        if n.contains("yellow") || n.contains("giallo") { return .yellow }
        if n.contains("green") || n.contains("verde") { return .green }
        if n.contains("blue") || n.contains("blu") { return .blue }
        if n.contains("purple") || n.contains("viola") { return .purple }
        if n.contains("gray") || n.contains("grey") || n.contains("grigio") { return .gray }
        return nil
    }
}
