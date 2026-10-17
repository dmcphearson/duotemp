import CoreLocation
import WeatherKit

/// Apple WeatherKit. Needs the WeatherKit capability and App Service enabled on the App ID.
enum AppleWeatherClient {
    static func snapshot(latitude: Double, longitude: Double, placeName: String, timeZoneID: String?) async throws -> WeatherSnapshot {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let (current, hourly, daily) = try await WeatherService.shared.weather(for: location, including: .current, .hourly, .daily)
        return makeSnapshot(current: current, hourly: hourly, daily: daily, placeName: placeName, timeZoneID: timeZoneID, now: .now)
    }

    static func detail(latitude: Double, longitude: Double, placeName: String, timeZoneID: String?) async throws -> ForecastDetail {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let now = Date()
        let start = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        let (current, hourly, daily) = try await WeatherService.shared.weather(
            for: location,
            including: .current, .hourly(startDate: start, endDate: start.addingTimeInterval(48 * 3600)), .daily
        )
        let snapshot = makeSnapshot(current: current, hourly: hourly, daily: daily, placeName: placeName, timeZoneID: timeZoneID, now: now)

        let hours = hourly.forecast.map { hour in
            ForecastDetail.Hour(
                date: hour.date,
                temperature: DualTemp(hour.temperature),
                symbolName: hour.symbolName,
                precipitationMM: hour.precipitationAmount.converted(to: .millimeters).value,
                precipitationChance: hour.precipitationChance
            )
        }
        let days = daily.forecast.prefix(10).map { day in
            ForecastDetail.Day(
                date: day.date,
                symbolName: day.symbolName,
                high: DualTemp(day.highTemperature),
                low: DualTemp(day.lowTemperature),
                precipitationMM: day.precipitationAmountByType.precipitation.converted(to: .millimeters).value,
                precipitationChance: day.precipitationChance
            )
        }
        let today = daily.forecast.first
        let conditions = ForecastDetail.Conditions(
            windSpeed: current.wind.speed.converted(to: .metersPerSecond).value,
            windDirection: current.wind.direction.converted(to: .degrees).value,
            windGust: current.wind.gust?.converted(to: .metersPerSecond).value,
            humidity: current.humidity,
            uvIndex: current.uvIndex.value,
            pressure: current.pressure.converted(to: .hectopascals).value,
            dewPoint: DualTemp(current.dewPoint),
            visibility: current.visibility.converted(to: .meters).value,
            sunrise: today?.sun.sunrise,
            sunset: today?.sun.sunset
        )

        var sources: [ForecastDetail.Field: WeatherSource] = [:]
        for field in ForecastDetail.Field.allCases { sources[field] = .apple }
        if conditions.windGust == nil { sources[.gusts] = nil }
        if conditions.sunrise == nil, conditions.sunset == nil { sources[.sun] = nil }

        return ForecastDetail(snapshot: snapshot, hours: hours, days: Array(days), conditions: conditions, sources: sources)
    }

    private static func makeSnapshot(
        current: CurrentWeather,
        hourly: Forecast<HourWeather>,
        daily: Forecast<DayWeather>,
        placeName: String,
        timeZoneID: String?,
        now: Date
    ) -> WeatherSnapshot {
        let hours = hourly.forecast
            .filter { $0.date > now }
            .prefix(12)
            .map { hour in
                WeatherSnapshot.Hour(
                    date: hour.date,
                    temperature: DualTemp(hour.temperature),
                    feelsLike: DualTemp(hour.apparentTemperature),
                    condition: hour.condition.description,
                    symbolName: hour.symbolName,
                    isDaylight: hour.isDaylight
                )
            }
        let today = daily.forecast.first

        return WeatherSnapshot(
            placeName: placeName,
            timeZoneID: timeZoneID,
            source: .apple,
            fetchedAt: now,
            current: WeatherSnapshot.Hour(
                date: current.date,
                temperature: DualTemp(current.temperature),
                feelsLike: DualTemp(current.apparentTemperature),
                condition: current.condition.description,
                symbolName: current.symbolName,
                isDaylight: current.isDaylight
            ),
            high: DualTemp(today?.highTemperature ?? current.temperature),
            low: DualTemp(today?.lowTemperature ?? current.temperature),
            hours: Array(hours)
        )
    }
}
