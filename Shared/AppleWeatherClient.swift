import CoreLocation
import WeatherKit

/// Apple WeatherKit. Needs the WeatherKit capability and App Service enabled on the App ID.
enum AppleWeatherClient {
    static func snapshot(latitude: Double, longitude: Double, placeName: String, timeZoneID: String?) async throws -> WeatherSnapshot {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let (current, hourly, daily) = try await WeatherService.shared.weather(for: location, including: .current, .hourly, .daily)
        let now = Date()

        let hours = hourly.forecast
            .filter { $0.date > now }
            .prefix(12)
            .map { hour in
                WeatherSnapshot.Hour(
                    date: hour.date,
                    temperature: DualTemp(hour.temperature),
                    feelsLike: DualTemp(hour.apparentTemperature),
                    condition: hour.condition.description,
                    symbolName: hour.symbolName
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
                symbolName: current.symbolName
            ),
            high: DualTemp(today?.highTemperature ?? current.temperature),
            low: DualTemp(today?.lowTemperature ?? current.temperature),
            hours: Array(hours)
        )
    }
}
