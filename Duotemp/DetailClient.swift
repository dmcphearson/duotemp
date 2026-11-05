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
            async let appleFetch = try? appleDetail(for: target)
            async let sun = try? METClient.sun(latitude: target.latitude, longitude: target.longitude, on: now, timeZone: timeZone)

            let forecast = try await METClient.forecast(latitude: target.latitude, longitude: target.longitude)
            // Rain codes are checked against Apple's chance of rain: from the Apple detail when WeatherKit
            // answered, else from AppleExtras, which shares its cache with the list and widgets.
            let apple = await appleFetch
            var rainChances = Self.chances(apple?.hours.map { ($0.date, $0.precipitationChance) } ?? [])
            if rainChances.isEmpty {
                rainChances = await AppleExtras.fetch(latitude: target.latitude, longitude: target.longitude)?.rainChances ?? [:]
            }
            let dayChances = Self.chances(apple?.days.map { ($0.date, $0.precipitationChance) } ?? [])
            let snapshot = try forecast.snapshot(placeName: target.name, timeZoneID: target.timeZoneID, fetchedAt: now, rainChances: rainChances)
            var detail = forecast.detail(snapshot: snapshot, now: now, rainChances: rainChances, dayChances: dayChances)
            if let sun = await sun, sun.sunrise != nil || sun.sunset != nil {
                detail.conditions.sunrise = sun.sunrise
                detail.conditions.sunset = sun.sunset
                detail.sources[.sun] = .yr
            }
            return detail.backfilled(from: apple)
        }
    }

    private static func chances(_ pairs: [(Date, Double?)]) -> [Date: Double] {
        var result: [Date: Double] = [:]
        for (date, chance) in pairs where result[date] == nil {
            if let chance { result[date] = chance }
        }
        return result
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
