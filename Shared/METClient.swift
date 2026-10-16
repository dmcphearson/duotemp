import Foundation
import OSLog

/// MET Norway Locationforecast 2.0, the data behind Yr. Follows https://api.met.no/doc/TermsOfService:
/// - identifies itself with a User-Agent naming the app and repo;
/// - rounds coordinates to 2 decimals (about 1 km; the terms allow at most 4);
/// - caches responses in the app group so the app and widgets share them, serving them until
///   `Expires` and then revalidating with `If-Modified-Since`.
enum METClient {
    private static let log = Logger(subsystem: "me.mcphearson.duotemp", category: "MET")

    static func snapshot(latitude: Double, longitude: Double, placeName: String, timeZoneID: String?) async throws -> WeatherSnapshot {
        var components = URLComponents(url: baseURL.appending(path: "locationforecast/2.0/complete"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.2f", latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.2f", longitude)),
        ]
        guard let url = components?.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200:
            break
        case 203:
            log.warning("[duotemp] MET Locationforecast 2.0 is deprecated; upgrade before it is removed")
        case 429:
            log.error("[duotemp] Error: MET rate limit (429)")
            throw METError.rateLimited
        default:
            log.error("[duotemp] Error: MET returned HTTP \(status)")
            throw METError.http(status)
        }
        return try METForecast.decode(data).snapshot(placeName: placeName, timeZoneID: timeZoneID, fetchedAt: .now)
    }

    /// `METBaseURL` from Info.plist (set by MET_BASE_URL in Config/Base.xcconfig), so release builds can use the proxy.
    private static var baseURL: URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "METBaseURL") as? String
        return configured.flatMap(URL.init(string:)) ?? URL(string: "https://api.met.no/weatherapi")!
    }

    private static var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return "duotemp/\(version) github.com/dmcphearson/duotemp"
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 2_000_000,
            diskCapacity: 20_000_000,
            directory: SharedStore.containerURL.appending(path: "METCache")
        )
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration)
    }()
}
