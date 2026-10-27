import Foundation

/// Maps a MET symbol code such as "lightrainshowers_night" to display text and an SF Symbol.
/// Codes: https://api.met.no/weatherapi/weathericon/2.0/documentation
struct METSymbol: Hashable, Sendable {
    let condition: String
    let symbolName: String
    /// The code's own sky when the icon shows something the sky can't draw (wind); nil when it's `symbolName`.
    let skySymbolName: String?

    /// Sustained wind in m/s from which a dry hour shows as breezy: Beaufort 5, fresh breeze.
    static let breezySpeed = 8.0
    /// Sustained wind in m/s from which a dry hour shows as windy: Beaufort 6, strong breeze.
    static let windySpeed = 10.8

    private init(_ condition: String, _ symbolName: String, sky: String? = nil) {
        self.condition = condition
        self.symbolName = symbolName
        skySymbolName = sky
    }

    /// MET's codes have no wind condition, so a dry, fog-free hour shows as breezy from `breezySpeed`
    /// and windy from `windySpeed`, like WeatherKit. Rain, sleet, snow, thunder and fog keep their icon.
    init(code: String, windSpeed: Double?) {
        let symbol = METSymbol(code: code)
        let base = code.split(separator: "_").first.map(String.init) ?? code
        guard let windSpeed, windSpeed >= Self.breezySpeed, ["clearsky", "fair", "partlycloudy", "cloudy"].contains(base) else {
            self = symbol
            return
        }
        self.init(windSpeed >= Self.windySpeed ? "Windy" : "Breezy", "wind", sky: symbol.symbolName)
    }

    init(code: String) {
        let parts = code.split(separator: "_", maxSplits: 1)
        var base = parts.first.map(String.init) ?? code
        let night = parts.count > 1 && parts[1] == "night"

        switch base {
        case "clearsky": self.init("Clear", night ? "moon.stars" : "sun.max"); return
        case "fair": self.init("Fair", night ? "cloud.moon" : "cloud.sun"); return
        case "partlycloudy": self.init("Partly Cloudy", night ? "cloud.moon" : "cloud.sun"); return
        case "cloudy": self.init("Cloudy", "cloud"); return
        case "fog": self.init("Fog", "cloud.fog"); return
        default: break
        }

        // Precipitation codes are [light|heavy]<rain|sleet|snow>[showers][andthunder].
        let thunder = base.hasSuffix("andthunder")
        if thunder { base.removeLast("andthunder".count) }
        let showers = base.hasSuffix("showers")
        if showers { base.removeLast("showers".count) }

        var intensity = ""
        if base.hasPrefix("lightss") {
            // MET spells two codes "lightssleet…" and "lightssnow…".
            intensity = "Light"
            base.removeFirst("lights".count)
        } else if base.hasPrefix("light") {
            intensity = "Light"
            base.removeFirst("light".count)
        } else if base.hasPrefix("heavy") {
            intensity = "Heavy"
            base.removeFirst("heavy".count)
        }

        guard ["rain", "sleet", "snow"].contains(base) else {
            self.init(code, "cloud")
            return
        }

        var words = [intensity, base.capitalized].filter { !$0.isEmpty }
        if showers { words.append("Showers") }
        var text = words.joined(separator: " ")
        if thunder { text += " and Thunder" }

        let symbol = switch (base, thunder) {
        case (_, true): base == "snow" ? "cloud.bolt" : "cloud.bolt.rain"
        // Heavy snow gets its own symbol so the sky can draw it heavier.
        case ("snow", _): intensity == "Heavy" ? "snowflake" : "cloud.snow"
        case ("sleet", _): "cloud.sleet"
        default:
            if intensity == "Heavy" { "cloud.heavyrain" }
            else if showers { night ? "cloud.moon.rain" : "cloud.sun.rain" }
            else if intensity == "Light" { "cloud.drizzle" }
            else { "cloud.rain" }
        }
        self.init(text, symbol)
    }
}
