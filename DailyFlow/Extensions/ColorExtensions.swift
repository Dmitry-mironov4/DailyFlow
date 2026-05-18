import SwiftUI

extension Color {
    static let bgPrimary       = Color(hex: 0x0D0A05)  // тёмный шоколад
    static let bgCard          = Color(hex: 0x1C1409)  // тёмная карамель
    static let bgPixelInactive = Color(hex: 0x362A14)  // поджаренная карамель
    static let accentTeal      = Color(hex: 0xD4882A)  // жидкая карамель — главный акцент
    static let accentAmber     = Color(hex: 0xE8C46A)  // золотистая карамель
    static let accentPurple    = Color(hex: 0xB8622A)  // корица, глубокий тон
    static let textPrimary     = Color(hex: 0xF0E8D8)  // тёплый кремовый белый
    static let textSecondary   = Color(hex: 0x8A7860)  // тёплый серо-коричневый
    static let textGhost       = Color(hex: 0x5E4E38)  // тёмная карамель-тень

    // Палитра привычек
    static let habitMint  = Color(hex: 0x3ECFB2)
    static let habitCoral = Color(hex: 0xFF6B6B)
    static let habitSky   = Color(hex: 0x5BA4F5)
    static let habitOlive = Color(hex: 0x8BBF4D)
    static let habitRose  = Color(hex: 0xE8789A)

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
