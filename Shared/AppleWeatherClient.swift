import CoreLocation
import WeatherKit

/// Apple WeatherKit. Needs the WeatherKit capability and App Service enabled on the App ID.
enum AppleWeatherClient {
    static func snapshot(latitude: Double, longitude: Double, placeName: String, timeZoneID: String?) async throws -> WeatherSnapshot {
        let location = CLLocation(approximateLatitude: latitude, longitude: longitude)
        // Alerts ride along: a request counts as one call however many data sets it includes.
        let (current, hourly, daily, alerts) = try await WeatherService.shared.weather(for: location, including: .current, .hourly, .daily, .alerts)
        var snapshot = makeSnapshot(current: current, hourly: hourly, daily: daily, location: location, placeName: placeName, timeZoneID: timeZoneID, now: .now)
        snapshot.alerts = activeAlerts(alerts)
        return snapshot
    }

    /// Alerts alone, for places whose forecast comes from Yr.
    static func alerts(latitude: Double, longitude: Double) async throws -> [ActiveAlert] {
        let location = CLLocation(approximateLatitude: latitude, longitude: longitude)
        return activeAlerts(try await WeatherService.shared.weather(for: location, including: .alerts))
    }

    /// Nil from WeatherKit (no alert service in that country) reads as none.
    private static func activeAlerts(_ alerts: [WeatherAlert]?) -> [ActiveAlert] {
        (alerts ?? []).map { alert in
            ActiveAlert(
                summary: alert.summary,
                region: alert.region,
                source: alert.source,
                severity: ActiveAlert.Severity(rawValue: alert.severity.rawValue) ?? .unknown,
                detailsURL: alert.detailsURL
            )
        }
    }

    static func detail(latitude: Double, longitude: Double, placeName: String, timeZoneID: String?) async throws -> ForecastDetail {
        let location = CLLocation(approximateLatitude: latitude, longitude: longitude)
        let now = Date()
        let start = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        let (current, hourly, daily, alerts) = try await WeatherService.shared.weather(
            for: location,
            including: .current, .hourly(startDate: start, endDate: start.addingTimeInterval(48 * 3600)), .daily, .alerts
        )
        var snapshot = makeSnapshot(current: current, hourly: hourly, daily: daily, location: location, placeName: placeName, timeZoneID: timeZoneID, now: now)
        snapshot.alerts = activeAlerts(alerts)

        let hours = hourly.forecast.map { hour in
            ForecastDetail.Hour(
                date: hour.date,
                temperature: DualTemp(hour.temperature),
                symbolName: hour.symbolName,
                precipitationMM: hour.precipitationAmount.converted(to: .millimeters).value,
                precipitationChance: hour.precipitationChance,
                cloudCover: hour.cloudCover
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
            pressureTrend: pressureTrend(current.pressureTrend),
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

    private static func pressureTrend(_ trend: PressureTrend) -> ForecastDetail.PressureTrend {
        switch trend {
        case .rising: .rising
        case .falling: .falling
        default: .steady
        }
    }

    private static func makeSnapshot(
        current: CurrentWeather,
        hourly: Forecast<HourWeather>,
        daily: Forecast<DayWeather>,
        location: CLLocation,
        placeName: String,
        timeZoneID: String?,
        now: Date
    ) -> WeatherSnapshot {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
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
                    isDaylight: hour.isDaylight,
                    sunProgress: Solar.dayProgress(at: hour.date, latitude: latitude, longitude: longitude),
                    sunElevation: Solar.elevation(at: hour.date, latitude: latitude, longitude: longitude),
                    windSpeed: hour.wind.speed.converted(to: .metersPerSecond).value,
                    windFromDirection: hour.wind.direction.converted(to: .degrees).value
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
                isDaylight: current.isDaylight,
                sunProgress: Solar.dayProgress(at: current.date, latitude: latitude, longitude: longitude),
                sunElevation: Solar.elevation(at: current.date, latitude: latitude, longitude: longitude),
                windSpeed: current.wind.speed.converted(to: .metersPerSecond).value,
                windFromDirection: current.wind.direction.converted(to: .degrees).value
            ),
            high: DualTemp(today?.highTemperature ?? current.temperature),
            low: DualTemp(today?.lowTemperature ?? current.temperature),
            hours: Array(hours)
        )
    }
}

extension CLLocation {
    /// Rounded to 2 decimals (about 1 km), the same precision MET gets, so Apple's services never see an exact position.
    convenience init(approximateLatitude latitude: Double, longitude: Double) {
        self.init(latitude: (latitude * 100).rounded() / 100, longitude: (longitude * 100).rounded() / 100)
    }
}
