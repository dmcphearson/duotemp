import Foundation

/// A place the detail screen can load.
struct DetailTarget: Hashable, Sendable {
    let key: String
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZoneID: String?
}

enum DetailClient {
    /// Yr primary: MET forecast and sun times, with Apple filling chance of rain, gusts and visibility
    /// when WeatherKit is available. Apple primary: everything from Apple.
    static func detail(primary: WeatherSource, target: DetailTarget) async throws -> ForecastDetail {
        switch primary {
        case .apple:
            return try await AppleWeatherClient.detail(
                latitude: target.latitude, longitude: target.longitude,
                placeName: target.name, timeZoneID: target.timeZoneID
            )
        case .yr:
            let now = Date()
            let timeZone = target.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
            async let apple = try? AppleWeatherClient.detail(
                latitude: target.latitude, longitude: target.longitude,
                placeName: target.name, timeZoneID: target.timeZoneID
            )
            async let sun = try? METClient.sun(latitude: target.latitude, longitude: target.longitude, on: now, timeZone: timeZone)

            let forecast = try await METClient.forecast(latitude: target.latitude, longitude: target.longitude)
            let snapshot = try forecast.snapshot(placeName: target.name, timeZoneID: target.timeZoneID, fetchedAt: now)
            var detail = forecast.detail(snapshot: snapshot, now: now)
            if let sun = await sun, sun.sunrise != nil || sun.sunset != nil {
                detail.conditions.sunrise = sun.sunrise
                detail.conditions.sunset = sun.sunset
                detail.sources[.sun] = .yr
            }
            return detail.backfilled(from: await apple)
        }
    }
}
