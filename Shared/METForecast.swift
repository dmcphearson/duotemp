import Foundation

/// The parts of a Locationforecast 2.0 "complete" response that duotemp uses.
/// Decode with `.convertFromSnakeCase` and `.iso8601` dates.
struct METForecast: Decodable, Sendable {
    struct Geometry: Decodable, Sendable {
        /// Longitude, latitude and altitude.
        let coordinates: [Double]
    }

    struct Properties: Decodable, Sendable {
        let timeseries: [Step]
    }

    struct Step: Decodable, Sendable {
        let time: Date
        let data: StepData
    }

    struct StepData: Decodable, Sendable {
        let instant: Instant
        let next1Hours: Period?
        let next6Hours: Period?
    }

    struct Instant: Decodable, Sendable {
        let details: Details
    }

    struct Details: Decodable, Sendable {
        let airTemperature: Double
        let apparentAirTemperature: Double?
        let windSpeed: Double?
        let windFromDirection: Double?
        let relativeHumidity: Double?
        /// Clear-sky UV, an upper bound; MET doesn't forecast cloud-adjusted UV.
        let ultravioletIndexClearSky: Double?
        let airPressureAtSeaLevel: Double?
        let dewPointTemperature: Double?
    }

    struct Period: Decodable, Sendable {
        let summary: Summary
        let details: PeriodDetails?
    }

    struct PeriodDetails: Decodable, Sendable {
        let airTemperatureMax: Double?
        let airTemperatureMin: Double?
        let precipitationAmount: Double?
    }

    struct Summary: Decodable, Sendable {
        let symbolCode: String
    }

    let geometry: Geometry?
    let properties: Properties

    static func decode(_ data: Data) throws -> METForecast {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(METForecast.self, from: data)
    }

    func snapshot(placeName: String, timeZoneID: String?, fetchedAt now: Date) throws -> WeatherSnapshot {
        let steps = properties.timeseries.sorted { $0.time < $1.time }
        let point = geometry?.coordinates

        // Hourly steps carry next_1_hours; the long-range tail is 6-hourly and is dropped.
        let hourly: [WeatherSnapshot.Hour] = steps.compactMap { step in
            guard let code = step.data.next1Hours?.summary.symbolCode else { return nil }
            let symbol = METSymbol(code: code)
            let details = step.data.instant.details
            return WeatherSnapshot.Hour(
                date: step.time,
                temperature: DualTemp(celsius: details.airTemperature),
                feelsLike: DualTemp(celsius: details.apparentAirTemperature ?? details.airTemperature),
                condition: symbol.condition,
                symbolName: symbol.symbolName,
                isDaylight: point.flatMap { $0.count >= 2 ? Solar.isDaylight(at: step.time, latitude: $0[1], longitude: $0[0]) : nil },
                sunProgress: point.flatMap { $0.count >= 2 ? Solar.dayProgress(at: step.time, latitude: $0[1], longitude: $0[0]) : nil }
            )
        }
        guard let current = hourly.last(where: { $0.date <= now }) ?? hourly.first else {
            throw METError.noData
        }

        // High and low over the rest of today in the location's time zone, including the 6-hour
        // extremes MET forecasts between hourly points. SharedStore widens this with earlier
        // fetches from the same day, since the forecast never covers hours already past.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
        let today = steps.filter { $0.time >= current.date && calendar.isDate($0.time, inSameDayAs: now) }
        var temperatures = today.map(\.data.instant.details.airTemperature)
        for step in today {
            if let max = step.data.next6Hours?.details?.airTemperatureMax { temperatures.append(max) }
            if let min = step.data.next6Hours?.details?.airTemperatureMin { temperatures.append(min) }
        }
        if temperatures.isEmpty { temperatures = [current.temperature.celsius] }

        return WeatherSnapshot(
            placeName: placeName,
            timeZoneID: timeZoneID,
            source: .yr,
            fetchedAt: now,
            current: current,
            high: DualTemp(celsius: temperatures.max() ?? current.temperature.celsius),
            low: DualTemp(celsius: temperatures.min() ?? current.temperature.celsius),
            hours: hourly.filter { $0.date > current.date }
        )
    }
}

enum METError: LocalizedError {
    case rateLimited
    case http(Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .rateLimited: "MET Norway is limiting requests. Try again later."
        case .http(let status): "MET Norway returned HTTP \(status)."
        case .noData: "MET Norway returned no hourly forecast."
        }
    }
}
