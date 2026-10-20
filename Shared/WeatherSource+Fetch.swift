import Foundation
import OSLog

private let log = Logger(subsystem: "me.mcphearson.duotemp", category: "Snapshot")

extension WeatherSource {
    /// WeatherKit is metered, so an Apple snapshot is reused for this long.
    static let appleMaxAge: TimeInterval = 30 * 60

    func snapshot(latitude: Double, longitude: Double, placeName: String, timeZoneID: String?) async throws -> WeatherSnapshot {
        switch self {
        case .yr:
            // MET responses are cached by the shared URLCache until the proxy's max-age.
            return try await METClient.snapshot(latitude: latitude, longitude: longitude, placeName: placeName, timeZoneID: timeZoneID)
        case .apple:
            if let cached = SharedStore.cachedAppleSnapshot(latitude: latitude, longitude: longitude, placeName: placeName, timeZoneID: timeZoneID, maxAge: Self.appleMaxAge) {
                log.debug("[duotemp] WeatherKit snapshot from cache")
                return cached
            }
            log.debug("[duotemp] WeatherKit snapshot fetch")
            let snapshot = try await AppleWeatherClient.snapshot(latitude: latitude, longitude: longitude, placeName: placeName, timeZoneID: timeZoneID)
            SharedStore.cacheAppleSnapshot(snapshot, latitude: latitude, longitude: longitude, maxAge: Self.appleMaxAge)
            return snapshot
        }
    }
}
