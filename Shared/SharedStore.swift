import Foundation

struct SavedLocation: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneID: String?
}

struct Coordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

/// Settings and cached forecasts shared by the app and the widget extension through the app group.
enum SharedStore {
    static let currentLocationKey = "current"

    /// "group.<app bundle ID>", derived so forks only change BUNDLE_ID_PREFIX.
    static var appGroupID: String {
        let bundleID = Bundle.main.bundleIdentifier ?? "me.mcphearson.duotemp"
        let appID = bundleID.hasSuffix(".widgets") ? String(bundleID.dropLast(".widgets".count)) : bundleID
        return "group.\(appID)"
    }

    /// The app group container, or Caches when the group isn't available (unsigned builds).
    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    static var leadUnit: LeadUnit {
        get { defaults.string(forKey: "leadUnit").flatMap(LeadUnit.init(rawValue:)) ?? .celsius }
        set { defaults.set(newValue.rawValue, forKey: "leadUnit") }
    }

    static var source: WeatherSource {
        get { defaults.string(forKey: "source").flatMap(WeatherSource.init(rawValue:)) ?? .yr }
        set { defaults.set(newValue.rawValue, forKey: "source") }
    }

    static var locations: [SavedLocation] {
        get { read([SavedLocation].self, "locations") ?? [] }
        set { write(newValue, "locations") }
    }

    /// Last fix from the app or a widget; widgets fall back to it when a new fix times out.
    static var lastKnownCoordinate: Coordinate? {
        get { read(Coordinate.self, "lastKnownCoordinate") }
        set { write(newValue, "lastKnownCoordinate") }
    }

    struct ProxyToken: Codable, Sendable {
        let value: String
        let expires: Date
    }

    /// The App Attest token for duoTemp's proxy; the app writes it, the app and widgets send it.
    static var proxyToken: ProxyToken? {
        get { read(ProxyToken.self, "proxyToken") }
        set { write(newValue, "proxyToken") }
    }

    static func cachedSnapshot(source: WeatherSource, key: String) -> WeatherSnapshot? {
        read(WeatherSnapshot.self, cacheKey(source, key))
    }

    /// Saves a fresh snapshot, widening today's high and low with the cached one, and returns what was saved.
    @discardableResult
    static func cache(_ snapshot: WeatherSnapshot, key: String) -> WeatherSnapshot {
        let merged = snapshot.widened(with: cachedSnapshot(source: snapshot.source, key: key))
        write(merged, cacheKey(snapshot.source, key))
        return merged
    }

    static func removeCache(key: String) {
        for source in WeatherSource.allCases {
            defaults.removeObject(forKey: cacheKey(source, key))
        }
        defaults.removeObject(forKey: appleDetailKey(key))
    }

    /// Apple Weather's detail for a place, while it's younger than `maxAge` and the place hasn't moved more
    /// than ~1 km, so reopening a place doesn't spend another WeatherKit call.
    static func cachedAppleDetail(key: String, latitude: Double, longitude: Double, maxAge: TimeInterval, now: Date = .now) -> ForecastDetail? {
        guard let cached = read(CachedAppleDetail.self, appleDetailKey(key)),
              now.timeIntervalSince(cached.fetchedAt) < maxAge,
              abs(cached.latitude - latitude) < 0.01, abs(cached.longitude - longitude) < 0.01
        else { return nil }
        return cached.detail
    }

    static func cacheAppleDetail(_ detail: ForecastDetail, key: String, latitude: Double, longitude: Double, fetchedAt: Date = .now) {
        write(CachedAppleDetail(latitude: latitude, longitude: longitude, fetchedAt: fetchedAt, detail: detail), appleDetailKey(key))
    }

    /// Apple Weather's snapshot for a place while it's younger than `maxAge`, shared by the app and widgets so
    /// foregrounding, pull to refresh and widget reloads don't each spend WeatherKit calls.
    static func cachedAppleSnapshot(latitude: Double, longitude: Double, placeName: String, timeZoneID: String?, maxAge: TimeInterval, now: Date = .now) -> WeatherSnapshot? {
        guard let snapshot = read([String: WeatherSnapshot].self, appleSnapshotsKey)?[coordinateKey(latitude, longitude)],
              now.timeIntervalSince(snapshot.fetchedAt) < maxAge,
              snapshot.placeName == placeName, snapshot.timeZoneID == timeZoneID
        else { return nil }
        return snapshot
    }

    /// Saves an Apple snapshot and drops entries older than `maxAge`, so places passed through don't pile up.
    static func cacheAppleSnapshot(_ snapshot: WeatherSnapshot, latitude: Double, longitude: Double, maxAge: TimeInterval, now: Date = .now) {
        var all = (read([String: WeatherSnapshot].self, appleSnapshotsKey) ?? [:]).filter { now.timeIntervalSince($0.value.fetchedAt) < maxAge }
        all[coordinateKey(latitude, longitude)] = snapshot
        write(all, appleSnapshotsKey)
    }

    private static let appleSnapshotsKey = "appleSnapshots"

    /// Alerts for a Yr place while they're younger than `maxAge`, so refreshes don't each spend a WeatherKit call.
    static func cachedAlerts(latitude: Double, longitude: Double, maxAge: TimeInterval, now: Date = .now) -> [ActiveAlert]? {
        guard let cached = read([String: CachedAlerts].self, alertsKey)?[coordinateKey(latitude, longitude)],
              now.timeIntervalSince(cached.fetchedAt) < maxAge
        else { return nil }
        return cached.alerts
    }

    /// Saves a place's alerts and drops entries older than `maxAge`.
    static func cacheAlerts(_ alerts: [ActiveAlert], latitude: Double, longitude: Double, maxAge: TimeInterval, now: Date = .now) {
        var all = (read([String: CachedAlerts].self, alertsKey) ?? [:]).filter { now.timeIntervalSince($0.value.fetchedAt) < maxAge }
        all[coordinateKey(latitude, longitude)] = CachedAlerts(fetchedAt: now, alerts: alerts)
        write(all, alertsKey)
    }

    private static let alertsKey = "alerts"

    private struct CachedAlerts: Codable {
        let fetchedAt: Date
        let alerts: [ActiveAlert]
    }

    /// Coordinates at 2 decimals (~1 km), the precision every request already uses.
    private static func coordinateKey(_ latitude: Double, _ longitude: Double) -> String {
        String(format: "%.2f,%.2f", latitude, longitude)
    }

    private struct CachedAppleDetail: Codable {
        let latitude: Double
        let longitude: Double
        let fetchedAt: Date
        let detail: ForecastDetail
    }

    /// Place name and time zone for a coordinate rounded to ~1 km, so widgets don't reverse-geocode every refresh.
    static func cachedPlace(near coordinate: Coordinate) -> (name: String, timeZoneID: String?)? {
        guard let place = read(CachedPlace.self, "cachedPlace"), place.matches(coordinate) else { return nil }
        return (place.name, place.timeZoneID)
    }

    static func cachePlace(name: String, timeZoneID: String?, near coordinate: Coordinate) {
        write(CachedPlace(latitude: coordinate.latitude, longitude: coordinate.longitude, name: name, timeZoneID: timeZoneID), "cachedPlace")
    }

    private struct CachedPlace: Codable {
        let latitude: Double
        let longitude: Double
        let name: String
        let timeZoneID: String?

        func matches(_ coordinate: Coordinate) -> Bool {
            abs(latitude - coordinate.latitude) < 0.01 && abs(longitude - coordinate.longitude) < 0.01
        }
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private static func cacheKey(_ source: WeatherSource, _ key: String) -> String {
        "snapshot.\(source.rawValue).\(key)"
    }

    private static func appleDetailKey(_ key: String) -> String {
        "appleDetail.\(key)"
    }

    private static func read<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    private static func write<T: Encodable>(_ value: T?, _ key: String) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
