import Foundation

/// Everything the detail screen shows for one place. Built from the primary source; when that is
/// Yr, Apple Weather fills the fields Yr doesn't provide. `sources` records who supplied each field.
struct ForecastDetail: Codable, Sendable {
    struct Hour: Codable, Sendable, Identifiable {
        var id: Date { date }
        let date: Date
        let temperature: DualTemp
        let symbolName: String
        let precipitationMM: Double?
        /// 0...1
        var precipitationChance: Double?
        /// 0...1
        var cloudCover: Double? = nil
    }

    struct Day: Codable, Sendable, Identifiable {
        var id: Date { date }
        /// Start of the local day.
        let date: Date
        let symbolName: String
        let high: DualTemp
        let low: DualTemp
        let precipitationMM: Double?
        /// 0...1
        var precipitationChance: Double?
    }

    struct Conditions: Codable, Sendable {
        /// Metres per second.
        var windSpeed: Double?
        /// Degrees the wind blows from.
        var windDirection: Double?
        /// Metres per second.
        var windGust: Double?
        /// 0...1
        var humidity: Double?
        var uvIndex: Int?
        /// Hectopascals at sea level.
        var pressure: Double?
        var pressureTrend: PressureTrend?
        var dewPoint: DualTemp?
        /// Metres.
        var visibility: Double?
        var sunrise: Date?
        var sunset: Date?
    }

    enum PressureTrend: Codable, Sendable {
        case rising, steady, falling
    }

    enum Field: String, CaseIterable, Codable, Sendable {
        case temperature = "Temperature and feels-like"
        case conditions = "Conditions and icons"
        case forecast = "Hourly and daily forecast"
        case rainAmount = "Rain amount"
        case rainChance = "Chance of rain"
        case wind = "Wind speed and direction"
        case gusts = "Wind gusts"
        case humidity = "Humidity and dew point"
        case uv = "UV index"
        case pressure = "Pressure"
        case visibility = "Visibility"
        case sun = "Sunrise and sunset"
    }

    var snapshot: WeatherSnapshot
    var hours: [Hour]
    var days: [Day]
    var conditions: Conditions
    var sources: [Field: WeatherSource]

    /// Fills chance of rain, gusts, visibility and sun times from Apple where this detail has none.
    /// Temperatures, conditions and rain amounts always stay with the primary source.
    func backfilled(from apple: ForecastDetail?) -> ForecastDetail {
        guard let apple else { return self }
        var result = self

        let appleHours = Dictionary(apple.hours.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = snapshot.timeZone
        var filledChance = false
        for index in result.hours.indices where result.hours[index].precipitationChance == nil {
            if let chance = appleHours[result.hours[index].date]?.precipitationChance {
                result.hours[index].precipitationChance = chance
                filledChance = true
            }
        }
        for index in result.days.indices where result.days[index].precipitationChance == nil {
            let match = apple.days.first { calendar.isDate($0.date, inSameDayAs: result.days[index].date) }
            if let chance = match?.precipitationChance {
                result.days[index].precipitationChance = chance
                filledChance = true
            }
        }
        if filledChance { result.sources[.rainChance] = .apple }

        if result.conditions.windGust == nil, let gust = apple.conditions.windGust {
            result.conditions.windGust = gust
            result.sources[.gusts] = .apple
        }
        if result.conditions.visibility == nil, let visibility = apple.conditions.visibility {
            result.conditions.visibility = visibility
            result.sources[.visibility] = .apple
        }
        if result.conditions.sunrise == nil, result.conditions.sunset == nil,
           apple.conditions.sunrise != nil || apple.conditions.sunset != nil {
            result.conditions.sunrise = apple.conditions.sunrise
            result.conditions.sunset = apple.conditions.sunset
            result.sources[.sun] = .apple
        }
        return result
    }
}
