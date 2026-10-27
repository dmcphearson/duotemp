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
        /// Metres per second, and the direction it blows from; leans the rain and snow.
        var windSpeed = 3.0
        var windFrom = 250.0
        /// Where the detail screen thinks the place is: it decides whether the northern lights card shows.
        var latitude = 53.35
        var longitude = -6.26
        var alerts: [ActiveAlert] = []
        /// The sky to draw when `symbol` is one the sky can't (wind).
        var sky: String? = nil
    }

    /// Shows the alert badge and the alert card with two alerts; the link is the agency's public warnings page.
    private static let sampleAlerts = [
        ActiveAlert(
            summary: "Orange Thunderstorm Warning", region: "Dublin", source: "Met Éireann",
            severity: .severe, detailsURL: URL(string: "https://www.met.ie/warnings")!
        ),
        ActiveAlert(
            summary: "Yellow Rain Warning", region: "Dublin", source: "Met Éireann",
            severity: .moderate, detailsURL: URL(string: "https://www.met.ie/warnings")!
        ),
    ]

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
        Sky(id: "drizzle", name: "Drizzle", condition: "Light Rain", symbol: "cloud.drizzle", isDaylight: true, sunProgress: 0.4, sunElevation: 20, celsius: 11, rainMM: 0.3, rainChance: 0.6, windSpeed: 2, windFrom: 270),
        Sky(id: "rain", name: "Rain", condition: "Rain", symbol: "cloud.rain", isDaylight: true, sunProgress: 0.45, sunElevation: 21, celsius: 10, rainMM: 1.4, rainChance: 0.85, windSpeed: 8, windFrom: 270),
        Sky(id: "heavy-rain", name: "Heavy Rain", condition: "Heavy Rain", symbol: "cloud.heavyrain", isDaylight: true, sunProgress: 0.55, sunElevation: 21, celsius: 10, rainMM: 4.2, rainChance: 0.95, windSpeed: 12, windFrom: 225),
        Sky(id: "thunderstorm", name: "Thunderstorm", condition: "Rain and Thunder", symbol: "cloud.bolt.rain", isDaylight: true, sunProgress: 0.6, sunElevation: 18, celsius: 13, rainMM: 5.1, rainChance: 0.9, windSpeed: 14, windFrom: 100, alerts: sampleAlerts),
        Sky(id: "snow", name: "Snow", condition: "Light Snow", symbol: "cloud.snow", isDaylight: true, sunProgress: 0.5, sunElevation: 12, celsius: -1, rainMM: 0.8, rainChance: 0.7, windSpeed: 1, windFrom: 0),
        Sky(id: "heavy-snow", name: "Heavy Snow", condition: "Heavy Snow", symbol: "snowflake", isDaylight: true, sunProgress: 0.5, sunElevation: 12, celsius: -3, rainMM: 3, rainChance: 0.95, windSpeed: 11, windFrom: 70),
        Sky(id: "fog", name: "Fog", condition: "Fog", symbol: "cloud.fog", isDaylight: true, sunProgress: 0.25, sunElevation: 9, celsius: 6),
        Sky(id: "windy", name: "Windy", condition: "Windy", symbol: "wind", isDaylight: true, sunProgress: 0.4, sunElevation: 22, celsius: 12, windSpeed: 13, windFrom: 270, sky: "cloud.sun"),
    ]

    /// App Store screenshots: real cities with chosen skies, shown as the main list by `-screenshotCities YES`.
    /// The first stands in for My Location.
    private static let cities: [Sky] = [
        Sky(id: "city-dublin", name: "Dublin", condition: "Partly Cloudy", symbol: "cloud.sun", isDaylight: true, sunProgress: 0.3, sunElevation: 20, celsius: 12, windSpeed: 6, windFrom: 250),
        Sky(id: "city-madrid", name: "Madrid", condition: "Clear", symbol: "sun.max", isDaylight: true, sunProgress: 0.45, sunElevation: 38, celsius: 24, latitude: 40.42, longitude: -3.7),
        Sky(id: "city-prague", name: "Prague", condition: "Clear", symbol: "sun.max", isDaylight: true, sunProgress: 0.97, sunElevation: 1.5, celsius: 14, latitude: 50.08, longitude: 14.44),
        Sky(id: "city-new-york", name: "New York", condition: "Rain and Thunder", symbol: "cloud.bolt.rain", isDaylight: true, sunProgress: 0.55, sunElevation: 30, celsius: 19, rainMM: 5.1, rainChance: 0.9, windSpeed: 11, windFrom: 200, latitude: 40.71, longitude: -74.01),
        Sky(id: "city-san-francisco", name: "San Francisco", condition: "Fog", symbol: "cloud.fog", isDaylight: true, sunProgress: 0.2, sunElevation: 8, celsius: 15, latitude: 37.77, longitude: -122.42),
        Sky(id: "city-reykjavik", name: "Reykjavík", condition: "Clear", symbol: "moon.stars", isDaylight: false, sunProgress: nil, sunElevation: -30, celsius: -1, latitude: 64.15, longitude: -21.94),
        Sky(id: "city-oslo", name: "Oslo", condition: "Heavy Snow", symbol: "snowflake", isDaylight: true, sunProgress: 0.5, sunElevation: 10, celsius: -4, rainMM: 3, rainChance: 0.95, windSpeed: 9, windFrom: 40, latitude: 59.91, longitude: 10.75),
    ]

    /// The time samples are dated at: 9:41 today while taking screenshots, matching the status bar;
    /// otherwise now. The hourly strip follows each sample's own time of day instead.
    static var clock: Date {
        guard UserDefaults.standard.bool(forKey: "screenshotCities") else { return .now }
        return Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: .now) ?? .now
    }

    static var keys: [String] { skies.map { keyPrefix + $0.id } }
    static var cityKeys: [String] { cities.map { keyPrefix + $0.id } }

    static func coordinate(for key: String) -> (latitude: Double, longitude: Double)? {
        sky(key).map { ($0.latitude, $0.longitude) }
    }

    static func isSample(_ key: String) -> Bool { key.hasPrefix(keyPrefix) }

    static func name(for key: String) -> String? { sky(key)?.name }

    static func snapshot(for key: String, now: Date = SampleSkies.clock) -> WeatherSnapshot? {
        guard let sky = sky(key) else { return nil }
        return makeSnapshot(sky, now: now)
    }

    static func detail(for key: String, now: Date = SampleSkies.clock) -> ForecastDetail? {
        guard let sky = sky(key) else { return nil }
        let snapshot = makeSnapshot(sky, now: now)
        let today = Calendar.current.startOfDay(for: now)
        // The strip is labelled with the sample's own time of day, not the clock, so a sunset or night
        // sky's hours read 7 PM or 11 PM onwards and their suns and moons fall at the right times.
        let firstHour = localHour(sky).rounded(.down)
        let hours = (0..<48).map { index -> ForecastDetail.Hour in
            let date = today.addingTimeInterval((firstHour + Double(index)) * 3600)
            let daylight = index == 0 ? sky.isDaylight : isDaylight(atHour: firstHour + Double(index) + 0.5)
            let celsius = sky.celsius + 3 * sin(Double(index) / 24 * 2 * .pi)
            return ForecastDetail.Hour(
                date: date,
                temperature: DualTemp(celsius: celsius),
                symbolName: symbol(sky.symbol, daylight: daylight),
                precipitationMM: sky.rainMM,
                precipitationChance: sky.rainChance
            )
        }
        let days = (0..<10).map { index in
            ForecastDetail.Day(
                // By calendar day, not 86,400 s: across a clock change that would land two rows on one day.
                date: Calendar.current.date(byAdding: .day, value: index, to: today) ?? today,
                symbolName: symbol(sky.symbol, daylight: true),
                high: DualTemp(celsius: sky.celsius + 4 + Double(index % 3)),
                low: DualTemp(celsius: sky.celsius - 3 - Double(index % 2)),
                precipitationMM: sky.rainMM * 12,
                precipitationChance: sky.rainChance
            )
        }
        let conditions = ForecastDetail.Conditions(
            windSpeed: sky.windSpeed,
            windDirection: sky.windFrom,
            windGust: sky.windSpeed * 1.6,
            humidity: sky.rainMM > 0 ? 0.94 : 0.72,
            uvIndex: sky.isDaylight ? 3 : 0,
            pressure: sky.rainMM > 3 ? 996 : 1018,
            pressureTrend: sky.rainMM > 3 ? .falling : .steady,
            dewPoint: DualTemp(celsius: sky.celsius - 2),
            visibility: sky.symbol == "cloud.fog" ? 600 : (sky.rainMM > 0 ? 8000 : 24000),
            sunrise: today.addingTimeInterval(sunriseHour * 3600),
            sunset: today.addingTimeInterval(sunsetHour * 3600)
        )
        var sources: [ForecastDetail.Field: WeatherSource] = [:]
        for field in ForecastDetail.Field.allCases { sources[field] = .yr }
        return ForecastDetail(snapshot: snapshot, hours: hours, days: days, conditions: conditions, sources: sources)
    }

    private static let sunriseHour = 7.9, sunsetHour = 18.4

    /// The sample's time of day in hours after midnight: a day sky from its progress between sunrise
    /// and sunset, a night sky an hour before midnight.
    private static func localHour(_ sky: Sky) -> Double {
        guard sky.isDaylight else { return 23 }
        return sunriseHour + (sky.sunProgress ?? 0.5) * (sunsetHour - sunriseHour)
    }

    private static func isDaylight(atHour hour: Double) -> Bool {
        let time = hour.truncatingRemainder(dividingBy: 24)
        return time >= sunriseHour && time < sunsetHour
    }

    /// The day or night form of a clear or partly cloudy symbol, so a night sky's forecast shows suns by day.
    private static func symbol(_ name: String, daylight: Bool) -> String {
        let pairs = ["sun.max": "moon.stars", "cloud.sun": "cloud.moon"]
        if daylight, let day = pairs.first(where: { $0.value == name })?.key { return day }
        if !daylight, let night = pairs[name] { return night }
        return name
    }

    private static func sky(_ key: String) -> Sky? {
        (skies + cities).first { keyPrefix + $0.id == key }
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
            sunElevation: sky.sunElevation,
            windSpeed: sky.windSpeed,
            windFromDirection: sky.windFrom,
            skySymbolName: sky.sky
        )
        return WeatherSnapshot(
            placeName: sky.name,
            timeZoneID: TimeZone.current.identifier,
            source: .yr,
            fetchedAt: now,
            current: current,
            high: DualTemp(celsius: sky.celsius + 4),
            low: DualTemp(celsius: sky.celsius - 3),
            hours: [],
            alerts: sky.alerts
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
