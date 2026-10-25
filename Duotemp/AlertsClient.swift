import Foundation
import OSLog

/// Alerts for places whose forecast comes from Yr, where the list makes no other WeatherKit call: one
/// alerts-only request per place, reused for 30 minutes. Apple snapshots and details include them already.
enum AlertsClient {
    static let maxAge: TimeInterval = 30 * 60

    private static let log = Logger(subsystem: "me.mcphearson.duotemp", category: "Alerts")

    /// Nil when WeatherKit fails; the row then shows no alert until the next refresh.
    static func alerts(latitude: Double, longitude: Double) async -> [ActiveAlert]? {
        if let cached = SharedStore.cachedAlerts(latitude: latitude, longitude: longitude, maxAge: maxAge) {
            return cached
        }
        do {
            let alerts = try await AppleWeatherClient.alerts(latitude: latitude, longitude: longitude)
            SharedStore.cacheAlerts(alerts, latitude: latitude, longitude: longitude, maxAge: maxAge)
            return alerts
        } catch {
            log.error("[duotemp] Error: alerts fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
