#if DEBUG
import Foundation

/// Made-up locations, one per sky, so every card, background and detail screen can be checked live.
/// Debug builds only; switched on in Settings.
enum SampleSkies {
    static let keyPrefix = "sample."

    private struct Sky {
        let id: String
        let name: String
        let condition: String
        let symbol: String
        let isDaylight: Bool
        let sunProgress: Double?
        let sunElevation: Double
        let celsius: Double
        var rainMM = 0.0
        var rainChance = 0.0
        var fullMoon = false
    }

    private static let skies: [Sky] = [
        Sky(id: "clear-day", name: "Clear Day", condition: "Clear", symbol: "sun.max", isDaylight: true, sunProgress: 0.35, sunElevation: 25, celsius: 16),
        Sky(id: "sunrise", name: "Sunrise", condition: "Clear", symbol: "sun.max", isDaylight: true, sunProgress: 0.02, sunElevation: 1, celsius: 7),
        Sky(id: "sunset", name: "Sunset", condition: "Partly Cloudy", symbol: "cloud.sun", isDaylight: true, sunProgress: 0.97, sunElevation: 1.5, celsius: 11),
        Sky(id: "partly-cloudy", name: "Partly Cloudy", condition: "Partly Cloudy", symbol: "cloud.sun", isDaylight: true, sunProgress: 0.6, sunElevation: 22, celsius: 14),
        Sky(id: "cloudy-day", name: "Cloudy Day", condition: "Cloudy", symbol: "cloud", isDaylight: true, sunProgress: 0.5, sunElevation: 24, celsius: 12),
        Sky(id: "twilight", name: "Twilight", condition: "Clear", symbol: "moon.stars", isDaylight: false, sunProgress: nil, sunElevation: -3, celsius: 9),
        Sky(id: "clear-night", name: "Clear Night", condition: "Clear", symbol: "moon.stars", isDaylight: false, sunProgress: nil, sunElevation: -30, celsius: 6),
        Sky(id: "full-moon", name: "Full Moon", condition: "Clear", symbol: "moon.stars", isDaylight: false, sunProgress: nil, sunElevation: -35, celsius: 4, fullMoon: true),
        Sky(id: "partly-cloudy-night", name: "Partly Cloudy Night", condition: "Partly Cloudy", symbol: "cloud.moon", isDaylight: false, sunProgress: nil, sunElevation: -25, celsius: 8),
        Sky(id: "cloudy-night", name: "Cloudy Night", condition: "Cloudy", symbol: "cloud", isDaylight: false, sunProgress: nil, sunElevation: -28, celsius: 9),
        Sky(id: "drizzle", name: "Drizzle", condition: "Light Rain", symbol: "cloud.drizzle", isDaylight: true, sunProgress: 0.4, sunElevation: 20, celsius: 11, rainMM: 0.3, rainChance: 0.6),
        Sky(id: "rain", name: "Rain", condition: "Rain", symbol: "cloud.rain", isDaylight: true, sunProgress: 0.45, sunElevation: 21, celsius: 10, rainMM: 1.4, rainChance: 0.85),
        Sky(id: "heavy-rain", name: "Heavy Rain", condition: "Heavy Rain", symbol: "cloud.heavyrain", isDaylight: true, sunProgress: 0.55, sunElevation: 21, celsius: 10, rainMM: 4.2, rainChance: 0.95),
        Sky(id: "thunderstorm", name: "Thunderstorm", condition: "Rain and Thunder", symbol: "cloud.bolt.rain", isDaylight: true, sunProgress: 0.6, sunElevation: 18, celsius: 13, rainMM: 5.1, rainChance: 0.9),
        Sky(id: "snow", name: "Snow", condition: "Light Snow", symbol: "cloud.snow", isDaylight: true, sunProgress: 0.5, sunElevation: 12, celsius: -1, rainMM: 0.8, rainChance: 0.7),
        Sky(id: "fog", name: "Fog", condition: "Fog", symbol: "cloud.fog", isDaylight: true, sunProgress: 0.25, sunElevation: 9, celsius: 6),
    ]

    static var keys: [String] { skies.map { keyPrefix + $0.id } }

    static func isSample(_ key: String) -> Bool { key.hasPrefix(keyPrefix) }

    static func name(for key: String) -> String? { sky(key)?.name }

    static func snapshot(for key: String, now: Date = .now) -> WeatherSnapshot? {
        guard let sky = sky(key) else { return nil }
        return makeSnapshot(sky, now: now)
    }

    static func detail(for key: String, now: Date = .now) -> ForecastDetail? {
        guard let sky = sky(key) else { return nil }
        let snapshot = makeSnapshot(sky, now: now)
        let start = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        let hours = (0..<48).map { index in
            ForecastDetail.Hour(
                date: start.addingTimeInterval(Double(index) * 3600),
                temperature: DualTemp(celsius: sky.celsius + 3 * sin(Double(index) / 24 * 2 * .pi)),
                symbolName: sky.symbol,
                precipitationMM: sky.rainMM,
                precipitationChance: sky.rainChance
            )
        }
        let today = Calendar.current.startOfDay(for: now)
        let days = (0..<7).map { index in
            ForecastDetail.Day(
                date: today.addingTimeInterval(Double(index) * 86400),
                symbolName: sky.symbol,
                high: DualTemp(celsius: sky.celsius + 4 + Double(index % 3)),
                low: DualTemp(celsius: sky.celsius - 3 - Double(index % 2)),
                precipitationMM: sky.rainMM * 12,
                precipitationChance: sky.rainChance
            )
        }
        let conditions = ForecastDetail.Conditions(
            windSpeed: sky.rainMM > 3 ? 11 : 4.5,
            windDirection: 230,
            windGust: sky.rainMM > 3 ? 19 : 8,
            humidity: sky.rainMM > 0 ? 0.94 : 0.72,
            uvIndex: sky.isDaylight ? 3 : 0,
            pressure: sky.rainMM > 3 ? 996 : 1018,
            pressureTrend: sky.rainMM > 3 ? .falling : .steady,
            dewPoint: DualTemp(celsius: sky.celsius - 2),
            visibility: sky.id == "fog" ? 600 : (sky.rainMM > 0 ? 8000 : 24000),
            sunrise: today.addingTimeInterval(7.9 * 3600),
            sunset: today.addingTimeInterval(18.4 * 3600)
        )
        var sources: [ForecastDetail.Field: WeatherSource] = [:]
        for field in ForecastDetail.Field.allCases { sources[field] = .yr }
        return ForecastDetail(snapshot: snapshot, hours: hours, days: days, conditions: conditions, sources: sources)
    }

    private static func sky(_ key: String) -> Sky? {
        skies.first { keyPrefix + $0.id == key }
    }

    private static func makeSnapshot(_ sky: Sky, now: Date) -> WeatherSnapshot {
        // The moon's phase follows the hour's date, so the full-moon sample is dated at the next full moon.
        let date = sky.fullMoon ? nextFullMoon(after: now) : now
        let current = WeatherSnapshot.Hour(
            date: date,
            temperature: DualTemp(celsius: sky.celsius),
            feelsLike: DualTemp(celsius: sky.celsius - 3),
            condition: sky.condition,
            symbolName: sky.symbol,
            isDaylight: sky.isDaylight,
            sunProgress: sky.sunProgress,
            sunElevation: sky.sunElevation
        )
        return WeatherSnapshot(
            placeName: sky.name,
            timeZoneID: TimeZone.current.identifier,
            source: .yr,
            fetchedAt: now,
            current: current,
            high: DualTemp(celsius: sky.celsius + 4),
            low: DualTemp(celsius: sky.celsius - 3),
            hours: []
        )
    }

    private static func nextFullMoon(after date: Date) -> Date {
        let month = 29.530588853 * 86400
        var wait = (0.5 - Lunar.phase(at: date)) * month
        if wait < 0 { wait += month }
        return date.addingTimeInterval(wait)
    }
}
#endif
