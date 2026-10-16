import SwiftUI

enum Theme {
    static let background = Color(hex: 0x12202B)
    static let card = Color(hex: 0x1F3240)
    static let secondary = Color(hex: 0xA9B8C3)
    static let accent = Color(hex: 0xF2B84B)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// "8°C" with the unit letter on the number's baseline at a smaller size.
struct TemperatureText: View {
    let temperature: DualTemp
    let unit: LeadUnit
    let size: CGFloat

    var body: some View {
        Text(temperature.degrees(unit)).font(.system(size: size, weight: .medium))
            + Text(unit.rawValue).font(.system(size: size * 0.45, weight: .medium))
    }
}

/// A weather SF Symbol in Apple's multicolor style (filled moon and stars, yellow sun, blue rain).
struct WeatherSymbol: View {
    let name: String
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: name)
            .symbolVariant(.fill)
            .symbolRenderingMode(.multicolor)
            .font(.system(size: size))
            .accessibilityHidden(true)
    }
}
