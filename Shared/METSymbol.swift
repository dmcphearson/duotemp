import Foundation

/// Maps a MET symbol code such as "lightrainshowers_night" to display text and an SF Symbol.
/// Codes: https://api.met.no/weatherapi/weathericon/2.0/documentation
struct METSymbol: Hashable, Sendable {
    let condition: String
    let symbolName: String

    private init(_ condition: String, _ symbolName: String) {
        self.condition = condition
        self.symbolName = symbolName
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
