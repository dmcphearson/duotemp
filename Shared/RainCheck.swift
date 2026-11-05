import Foundation

/// MET's rain codes follow a single model run's rain amount, and outside the Nordics that model forecasts
/// a tenth of a millimetre far more often than it rains. A MET rain code is shown only when Apple Weather's
/// chance of rain for the same hour (or day) agrees; without Apple, only when MET's amount is at least
/// `fallbackAmount`. Otherwise the period shows the cloud code for its cloud cover. Heavy rain, snow, sleet
/// and thunder codes are never changed: a forecast downpour is shown even when Apple disagrees.
enum RainCheck {
    /// Apple's chance of rain, 0...1, from which a MET rain code is kept.
    static let minimumChance = 0.4
    /// Millimetres in the period from which a rain code is kept when Apple's chance isn't known.
    static let fallbackAmount = 0.5

    /// The MET code to show for a period.
    /// - Parameters:
    ///   - amount: MET's precipitation for the period in millimetres; nil keeps the code when there's no chance either.
    ///   - chance: Apple's chance of rain, 0...1, nil when WeatherKit didn't answer for this period.
    ///   - cloudCover: MET's cloud area fraction in percent.
    ///   - isDaylight: picks the day or night variant of the replacement; nil reads as day.
    static func code(_ code: String, amount: Double?, chance: Double?, cloudCover: Double?, isDaylight: Bool?) -> String {
        guard isRain(code) else { return code }
        let agrees = if let chance { chance >= minimumChance } else { (amount ?? .infinity) >= fallbackAmount }
        guard !agrees else { return code }

        let cloud = switch cloudCover {
        case nil: "cloudy"
        case let percent? where percent >= 75: "cloudy"
        case let percent? where percent >= 40: "partlycloudy"
        case let percent? where percent >= 12.5: "fair"
        default: "clearsky"
        }
        return cloud == "cloudy" ? cloud : "\(cloud)_\(isDaylight ?? true ? "day" : "night")"
    }

    /// Light or moderate rain without snow, sleet or thunder, for example "lightrainshowers_day" or "rain".
    static func isRain(_ code: String) -> Bool {
        let base = code.split(separator: "_").first.map(String.init) ?? code
        return base.contains("rain") && !base.hasPrefix("heavy") && !base.contains("sleet") && !base.contains("snow")
            && !base.hasSuffix("andthunder")
    }
}
