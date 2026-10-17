import Foundation

/// Everything the app and widgets display for one place, independent of the data source.
struct WeatherSnapshot: Codable, Hashable, Sendable {
    struct Hour: Codable, Hashable, Sendable {
        let date: Date
        let temperature: DualTemp
        let feelsLike: DualTemp
        let condition: String
        /// SF Symbol base name; views apply the fill variant.
        let symbolName: String
        /// Whether the sun is up; nil in snapshots cached before this was recorded.
        var isDaylight: Bool? = nil
    }

    let placeName: String
    let timeZoneID: String?
    let source: WeatherSource
    let fetchedAt: Date
    let current: Hour
    let high: DualTemp
    let low: DualTemp
    /// Hourly forecast after `current`, oldest first.
    let hours: [Hour]

    var timeZone: TimeZone {
        timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
    }

    /// Conditions at `date`: the latest forecast hour that has started, else the fetched current conditions.
    /// Widget timelines use this to step through the forecast without refetching.
    func now(at date: Date) -> Hour {
        hours.last { $0.date <= date } ?? current
    }

    /// Today's high and low widened with an earlier fetch from the same local day and source.
    func widened(with earlier: WeatherSnapshot?) -> WeatherSnapshot {
        guard let earlier, earlier.source == source else { return self }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard calendar.isDate(earlier.fetchedAt, inSameDayAs: fetchedAt) else { return self }
        return WeatherSnapshot(
            placeName: placeName,
            timeZoneID: timeZoneID,
            source: source,
            fetchedAt: fetchedAt,
            current: current,
            high: DualTemp(celsius: max(high.celsius, earlier.high.celsius)),
            low: DualTemp(celsius: min(low.celsius, earlier.low.celsius)),
            hours: hours
        )
    }

    /// The next `count` forecast hours after `date`.
    func upcoming(after date: Date, count: Int = 6) -> [Hour] {
        Array(hours.filter { $0.date > date }.prefix(count))
    }
}
