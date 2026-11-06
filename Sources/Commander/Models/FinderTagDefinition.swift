import Foundation
import AppKit
import SwiftUI

/// Tag configurabile usato dal menu contestuale e dalle impostazioni.
/// I nomi predefiniti seguono la lingua di Finder (inglese o italiano).
struct FinderTagDefinition: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorIndex: Int

    var nsColor: NSColor { FinderTagPalette.nsColor(at: colorIndex) }
    var color: Color { Color(nsColor: nsColor) }
}

enum FinderTagPalette {
    static let colors: [NSColor] = [
        .systemRed,
        .systemOrange,
        .systemYellow,
        .systemGreen,
        .systemBlue,
        .systemPurple,
        .systemGray
    ]

    static let englishNames = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Gray"]
    static let italianNames = ["Rosso", "Arancione", "Giallo", "Verde", "Blu", "Viola", "Grigio"]

    static func nsColor(at index: Int) -> NSColor {
        colors.indices.contains(index) ? colors[index] : .systemGray
    }

    static func color(at index: Int) -> Color {
        Color(nsColor: nsColor(at: index))
    }

    static func defaultDefinitions() -> [FinderTagDefinition] {
        let names = L10n.isItalian ? italianNames : englishNames
        return names.enumerated().map { FinderTagDefinition(name: $0.element, colorIndex: $0.offset) }
    }
}
