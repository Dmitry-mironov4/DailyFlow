import SwiftUI

extension Color {
    static let bgPrimary = Color(hex: 0x0D0D0D)
    static let bgCard = Color(hex: 0x1A1A1A)
    static let accentTeal = Color(hex: 0x2DD4A0)
    static let accentAmber = Color(hex: 0xF0A23B)
    static let accentPurple = Color(hex: 0x9B8AE8)
    static let textPrimary = Color(hex: 0xF2F2F2)
    static let textSecondary = Color(hex: 0x888888)
    static let textGhost = Color(hex: 0x666666)

    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
