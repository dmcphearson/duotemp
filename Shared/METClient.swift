import Foundation
import OSLog

/// MET Norway Locationforecast 2.0 and Sunrise 3.0, the data behind Yr. Follows https://api.met.no/doc/TermsOfService:
/// - goes through duoTemp's caching proxy when the app holds a proxy token (`ProxyAccess`), which shares one
///   MET response between nearby users until its `Expires`; otherwise calls MET directly;
/// - identifies the app to MET with `UserAgent`;
/// - rounds coordinates to 2 decimals (about 1 km; the terms allow at most 4);
/// - caches responses in the app group so the app and widgets share them, serving them until `Expires`.
enum METClient {
    private static let log = Logger(subsystem: "me.mcphearson.duotemp", category: "MET")

    static func snapshot(latitude: Double, longitude: Double, placeName: String, timeZoneID: String?) async throws -> WeatherSnapshot {
        try await forecast(latitude: latitude, longitude: longitude)
            .snapshot(placeName: placeName, timeZoneID: timeZoneID, fetchedAt: .now)
    }

    static func forecast(latitude: Double, longitude: Double) async throws -> METForecast {
        try METForecast.decode(await get("locationforecast/2.0/complete", latitude: latitude, longitude: longitude))
    }

    /// Sunrise and sunset for the local day containing `date`; nil when the sun doesn't rise or set that day.
    static func sun(latitude: Double, longitude: Double, on date: Date, timeZone: TimeZone) async throws -> (sunrise: Date?, sunset: Date?) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let seconds = timeZone.secondsFromGMT(for: date)
        let offset = (seconds < 0 ? "-" : "+") + String(format: "%02d:%02d", abs(seconds) / 3600, abs(seconds) % 3600 / 60)

        let data = try await get("sunrise/3.0/sun", latitude: latitude, longitude: longitude, extra: [
            URLQueryItem(name: "date", value: day),
            URLQueryItem(name: "offset", value: offset),
        ])
        let response = try JSONDecoder().decode(SunResponse.self, from: data)
        return (parseSunTime(response.properties.sunrise?.time), parseSunTime(response.properties.sunset?.time))
    }

    private struct SunResponse: Decodable {
        struct Properties: Decodable {
            let sunrise: Event?
            let sunset: Event?
        }

        struct Event: Decodable {
            let time: String?
        }

        let properties: Properties
    }

    /// Sunrise times look like "2026-10-17T07:54+01:00" (no seconds), which ISO8601DateFormatter rejects.
    private static func parseSunTime(_ text: String?) -> Date? {
        guard let text else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mmxxxxx"
        return formatter.date(from: text)
    }

    private static func get(_ path: String, latitude: Double, longitude: Double, extra: [URLQueryItem] = []) async throws -> Data {
        let route = ProxyAccess.route()
        let base = route.map { $0.base.appending(path: "met") } ?? directURL
        guard var components = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.2f", latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.2f", longitude)),
        ] + extra
        // URLComponents leaves "+" unescaped, and the server would read it as a space.
        let query = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        components.percentEncodedQuery = query
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue(UserAgent.value, forHTTPHeaderField: "User-Agent")
        if let route { request.setValue(route.token, forHTTPHeaderField: ProxyAccess.tokenHeader) }
        let (data, response) = try await session.data(for: request)

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200:
            break
        case 203:
            log.warning("[duotemp] MET \(path) is deprecated; upgrade before it is removed")
        case 401 where route != nil:
            log.error("[duotemp] Error: proxy refused the token; calling MET directly")
            ProxyAccess.tokenRejected()
            return try await get(path, latitude: latitude, longitude: longitude, extra: extra)
        case 429:
            log.error("[duotemp] Error: MET rate limit (429) on \(path)")
            throw METError.rateLimited
        default:
            log.error("[duotemp] Error: MET returned HTTP \(status) on \(path)")
            throw METError.http(status)
        }
        return data
    }

    /// MET itself: `METBaseURL` from Info.plist (MET_BASE_URL in Config/Base.xcconfig).
    private static var directURL: URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "METBaseURL") as? String
        return configured.flatMap(URL.init(string:)) ?? URL(string: "https://api.met.no/weatherapi")!
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
