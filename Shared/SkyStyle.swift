import SwiftUI

/// Background for a widget or location card, chosen from the hour's symbol and whether the sun is up.
enum SkyStyle: String, CaseIterable, Sendable {
    case clearDay, cloudyDay, clearNight, cloudyNight, rain, snowOrFog

    init(hour: WeatherSnapshot.Hour) {
        self.init(symbolName: hour.symbolName, isDaylight: hour.isDaylight)
    }

    init(symbolName: String, isDaylight: Bool?) {
        let parts = Set(symbolName.split(separator: ".").map(String.init))
        if !parts.isDisjoint(with: ["snow", "sleet", "hail", "fog", "haze", "smoke", "dust", "snowflake"]) {
            self = .snowOrFog
        } else if !parts.isDisjoint(with: ["rain", "drizzle", "heavyrain", "bolt"]) {
            self = .rain
        } else if parts.contains("sun") {
            self = .clearDay
        } else if parts.contains("moon") {
            self = .clearNight
        } else {
            // Plain cloud, wind and similar symbols don't say whether it's day or night.
            self = isDaylight == false ? .cloudyNight : .cloudyDay
        }
    }

    var gradient: LinearGradient {
        let (top, bottom): (UInt32, UInt32) = switch self {
        case .clearDay: (0x1F5A8C, 0x2E6CA3)
        case .cloudyDay: (0x46525E, 0x56636F)
        case .clearNight: (0x0E1A33, 0x1E2E52)
        case .cloudyNight: (0x1B2430, 0x2B3644)
        case .rain: (0x26394A, 0x34495C)
        case .snowOrFog: (0x4A5866, 0x5D6B78)
        }
        return LinearGradient(colors: [Color(hex: top), Color(hex: bottom)], startPoint: .top, endPoint: .bottom)
    }

    /// Secondary text on any sky background.
    static let secondary = Color.white.opacity(0.82)
}

extension View {
    /// A faint shadow that keeps white text readable where it crosses the sun's glow.
    func skyTextShadow() -> some View {
        shadow(color: .black.opacity(0.22), radius: 3, y: 1)
    }
}
