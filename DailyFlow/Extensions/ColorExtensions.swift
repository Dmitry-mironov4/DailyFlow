import SwiftUI

extension Color {
    // Backgrounds
    static let bgPrimary = Color(hex: 0x111214)
    static let bgCard = Color(hex: 0x1A1C1F)
    static let bgElevated = Color(hex: 0x212427)

    // Separators
    static let separator = Color(hex: 0x2C2F33)
    static let borderCard = Color.white.opacity(0.06)

    // Accents
    static let accentWhite = Color(hex: 0xF5F5F5)
    static let accentDone = Color(hex: 0x4ADE80)
    static let accentDestructive = Color(hex: 0xF87171)

    // Text
    static let textPrimary = Color(hex: 0xDCDCDC)
    static let textSecondary = Color(hex: 0x808080)
    static let textGhost = Color(hex: 0x464646)
    static let textInverted = Color(hex: 0x111214)

    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    init(hex string: String) {
        let cleaned = string.hasPrefix("#") ? String(string.dropFirst()) : string
        self.init(hex: UInt32(cleaned, radix: 16) ?? 0)
    }
}
