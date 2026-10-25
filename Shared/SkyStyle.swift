import SwiftUI

/// Background for a widget or location card, chosen from the hour's symbol and whether the sun is up.
enum SkyStyle: String, CaseIterable, Sendable {
    case clearDay, cloudyDay, clearNight, cloudyNight, rain, storm, snow, fog, fogNight

    init(hour: WeatherSnapshot.Hour) {
        self.init(symbolName: hour.skySymbol, isDaylight: hour.isDaylight)
    }

    init(symbolName: String, isDaylight: Bool?) {
        let parts = Set(symbolName.split(separator: ".").map(String.init))
        if parts.contains("bolt") {
            self = .storm
        } else if !parts.isDisjoint(with: ["fog", "haze", "smoke", "dust"]) {
            self = isDaylight == false ? .fogNight : .fog
        } else if !parts.isDisjoint(with: ["snow", "sleet", "hail", "snowflake"]) {
            self = .snow
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

    var gradient: LinearGradient { gradient(glow: 0) }

    /// How strongly sunrise or sunset colours the sky, 0...1: strongest with the sun just above the
    /// horizon, fading by 8° up and by civil twilight's end (-6°) below. Cloud and rain mute it.
    func glow(sunElevation: Double?) -> Double {
        guard let elevation = sunElevation else { return 0 }
        let distance = elevation >= 1 ? (elevation - 1) / 7 : (1 - elevation) / 7
        let strength: Double = switch self {
        case .clearDay, .clearNight: 1
        case .cloudyDay, .cloudyNight: 0.55
        case .rain, .storm, .snow, .fog, .fogNight: 0.3
        }
        return max(0, 1 - distance) * strength
    }

    /// The same condition's day and night skies; styles without a night version return themselves.
    var dayVariant: SkyStyle {
        switch self {
        case .clearNight: .clearDay
        case .cloudyNight: .cloudyDay
        case .fogNight: .fog
        default: self
        }
    }

    var nightVariant: SkyStyle {
        switch self {
        case .clearDay: .clearNight
        case .cloudyDay: .cloudyNight
        case .fog: .fogNight
        default: self
        }
    }

    /// The condition gradient blended between its night (0) and day (1) skies, then warmed by `glow`.
    func gradient(daylight: Double, glow: Double) -> LinearGradient {
        let (dayTop, dayBottom) = dayVariant.colors
        let (nightTop, nightBottom) = nightVariant.colors
        return Self.gradient(top: nightTop.mix(with: dayTop, by: daylight), bottom: nightBottom.mix(with: dayBottom, by: daylight), glow: glow)
    }

    /// The condition gradient, warmed toward dusky violet, rose and amber by `glow`.
    func gradient(glow: Double) -> LinearGradient {
        let (top, bottom) = colors
        return Self.gradient(top: top, bottom: bottom, glow: glow)
    }

    private static func gradient(top: Color, bottom: Color, glow: Double) -> LinearGradient {
        let middle = top.mix(with: bottom, by: 0.5)
        return LinearGradient(
            stops: [
                .init(color: top.mix(with: Color(hex: 0x3A3F72), by: glow * 0.8), location: 0),
                .init(color: middle.mix(with: Color(hex: 0xB8607A), by: glow * 0.75), location: 0.55),
                .init(color: bottom.mix(with: Color(hex: 0xF2A65A), by: glow * 0.9), location: 1),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var colors: (Color, Color) {
        let (top, bottom): (UInt32, UInt32) = switch self {
        case .clearDay: (0x1F5A8C, 0x2E6CA3)
        case .cloudyDay: (0x46525E, 0x56636F)
        case .clearNight: (0x0E1A33, 0x1E2E52)
        case .cloudyNight: (0x1B2430, 0x2B3644)
        case .rain: (0x26394A, 0x34495C)
        case .storm: (0x1E1F33, 0x34344A)
        case .snow: (0x4A5866, 0x5D6B78)
        // Fog sits low, so it lightens toward the bottom.
        case .fog: (0x52606C, 0x76838F)
        case .fogNight: (0x1E2631, 0x3B4653)
        }
        return (Color(hex: top), Color(hex: bottom))
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
