import Foundation
import OSLog

/// A place the detail screen can load.
struct DetailTarget: Hashable, Sendable {
    let key: String
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZoneID: String?
}

enum DetailClient {
    /// WeatherKit is the app's metered dependency; a place's Apple detail is reused for this long.
    static let appleMaxAge: TimeInterval = 30 * 60

    private static let log = Logger(subsystem: "me.mcphearson.duotemp", category: "Detail")

    /// Yr primary: MET forecast and sun times, with Apple filling chance of rain, gusts and visibility
    /// when WeatherKit is available. Apple primary: everything from Apple.
    static func detail(primary: WeatherSource, target: DetailTarget) async throws -> ForecastDetail {
        switch primary {
        case .apple:
            return try await appleDetail(for: target)
        case .yr:
            let now = Date()
            let timeZone = target.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
            async let apple = try? appleDetail(for: target)
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

    /// Apple Weather's detail for the place, from the cache while it's fresh.
    private static func appleDetail(for target: DetailTarget) async throws -> ForecastDetail {
        if let cached = SharedStore.cachedAppleDetail(key: target.key, latitude: target.latitude, longitude: target.longitude, maxAge: appleMaxAge) {
            log.debug("[duotemp] WeatherKit detail from cache")
            return cached
        }
        log.debug("[duotemp] WeatherKit detail fetch")
        let detail = try await AppleWeatherClient.detail(
            latitude: target.latitude, longitude: target.longitude,
            placeName: target.name, timeZoneID: target.timeZoneID
        )
        SharedStore.cacheAppleDetail(detail, key: target.key, latitude: target.latitude, longitude: target.longitude)
        return detail
    }
}
