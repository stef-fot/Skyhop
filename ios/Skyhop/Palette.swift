import SwiftUI

/// Dusk palette, shared 1:1 with the Android version.
enum Palette {
    static let skyTop = Color(hex: 0x2E2A6B)
    static let skyMid = Color(hex: 0x8A5CB8)
    static let skyBottom = Color(hex: 0xF7A072)
    static let star = Color(hex: 0xFFF4D6)
    static let cloud = Color.white.opacity(0.18)
    static let hillFar = Color(hex: 0x6A4FA3)
    static let hillNear = Color(hex: 0x4B3B86)

    static let pipeLight = Color(hex: 0x6FE0CF)
    static let pipeMid = Color(hex: 0x2BB3A0)
    static let pipeDark = Color(hex: 0x1B7C70)

    static let ground = Color(hex: 0xF2C66D)
    static let groundShade = Color(hex: 0xD9A94F)
    static let grass = Color(hex: 0x4C8A45)
    static let grassLight = Color(hex: 0x63A55A)

    static let birdBody = Color(hex: 0xFFD23F)
    static let birdBelly = Color(hex: 0xFFE89A)
    static let birdWing = Color(hex: 0xF6A93B)
    static let beak = Color(hex: 0xF4845F)
    static let pupil = Color(hex: 0x1E1B3A)

    static let card = Color(hex: 0xFFF4E0)
    static let cardInk = Color(hex: 0x2E2A6B)
    static let cardMuted = Color(hex: 0x7A6F9B)
    static let badge = Color(hex: 0xF4845F)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
