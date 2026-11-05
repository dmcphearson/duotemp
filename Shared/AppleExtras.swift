import Foundation
import OSLog

/// WeatherKit's part of a Yr place: alerts and hourly chance of rain (for `RainCheck`), from one request,
/// since WeatherKit counts a request once however many data sets it includes. Reused for 30 minutes and
/// shared by the app and widgets through the App Group. Apple snapshots and details include both already.
enum AppleExtras {
    static let maxAge: TimeInterval = 30 * 60

    struct Extras: Codable, Sendable {
        var alerts: [ActiveAlert]
        /// Chance of rain, 0...1, by the start of each hour.
        var rainChances: [Date: Double]
    }

    private static let log = Logger(subsystem: "me.mcphearson.duotemp", category: "AppleExtras")

    /// Nil when WeatherKit fails: rows show no alert, and rain falls back to MET's amount.
    static func fetch(latitude: Double, longitude: Double) async -> Extras? {
        if let cached = SharedStore.cachedExtras(latitude: latitude, longitude: longitude, maxAge: maxAge) {
            return cached
        }
        do {
            let extras = try await AppleWeatherClient.extras(latitude: latitude, longitude: longitude)
            SharedStore.cacheExtras(extras, latitude: latitude, longitude: longitude, maxAge: maxAge)
            return extras
        } catch {
            log.error("[duotemp] Error: WeatherKit extras fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
