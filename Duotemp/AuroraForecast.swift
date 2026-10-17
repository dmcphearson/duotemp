import Foundation
import OSLog

/// Planetary Kp in 3-hour blocks for the next few days. GFZ Potsdam's ensemble forecast first,
/// NOAA SWPC's single forecast if GFZ is down (source preference: Europe, then Canada, then US).
struct KpForecast: Sendable {
    enum Source: Sendable {
        case gfz, noaa

        var credit: String {
            switch self {
            case .gfz: "Kp forecast by GFZ Potsdam, CC BY 4.0"
            case .noaa: "Kp forecast by NOAA SWPC"
            }
        }

        var url: URL {
            switch self {
            case .gfz: URL(string: "https://kp.gfz.de/en/")!
            case .noaa: URL(string: "https://www.swpc.noaa.gov/products/planetary-k-index")!
            }
        }
    }

    struct Block: Sendable {
        /// Start of the 3-hour block, UTC.
        let start: Date
        let median: Double
        /// Ensemble members; one value when the source has no ensemble.
        let members: [Double]
    }

    let source: Source
    let blocks: [Block]

    func block(at date: Date) -> Block? {
        blocks.last { $0.start <= date && date < $0.start.addingTimeInterval(3 * 3600) }
    }
}

enum AuroraClient {
    private static let log = Logger(subsystem: "me.mcphearson.duotemp", category: "Aurora")
    private static let gfzURL = URL(string: "https://spaceweather.gfz.de/fileadmin/Kp-Forecast/CSV/kp_product_file_FORECAST_PAGER_SWIFT_LAST.csv")!
    private static let noaaURL = URL(string: "https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json")!

    /// The forecast is global, so one fetch serves every location until it's 30 minutes old.
    private static let memo = Memo()

    static func forecast() async throws -> KpForecast {
        if let cached = await memo.value { return cached }
        let forecast: KpForecast
        do {
            forecast = try parseGFZ(try await get(gfzURL))
        } catch {
            log.warning("[duotemp] GFZ Kp forecast failed (\(error.localizedDescription)); trying NOAA")
            forecast = try parseNOAA(try await get(noaaURL))
        }
        await memo.store(forecast)
        return forecast
    }

    private actor Memo {
        private var stored: (forecast: KpForecast, at: Date)?

        var value: KpForecast? {
            guard let stored, Date().timeIntervalSince(stored.at) < 30 * 60 else { return nil }
            return stored.forecast
        }

        func store(_ forecast: KpForecast) {
            stored = (forecast, .now)
        }
    }

    private static func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        request.setValue("duotemp/\(version) github.com/dmcphearson/duotemp", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            log.error("[duotemp] Error: \(url.host() ?? "") returned HTTP \(status)")
            throw URLError(.badServerResponse)
        }
        return data
    }

    /// GFZ's CSV: "Time (UTC)" as dd-MM-yyyy HH:mm, then summary columns including "median", then kp_0…kp_n members.
    static func parseGFZ(_ data: Data) throws -> KpForecast {
        guard let text = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        let lines = text.split(whereSeparator: \.isNewline).map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
        guard let header = lines.first, let medianColumn = header.firstIndex(of: "median") else {
            throw URLError(.cannotParseResponse)
        }
        let memberColumns = header.indices.filter { header[$0].hasPrefix("kp_") }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "dd-MM-yyyy HH:mm"

        let blocks: [KpForecast.Block] = lines.dropFirst().compactMap { row in
            guard row.count > medianColumn, let start = formatter.date(from: row[0]), let median = Double(row[medianColumn]) else { return nil }
            let members = memberColumns.compactMap { $0 < row.count ? Double(row[$0]) : nil }
            return KpForecast.Block(start: start, median: median, members: members.isEmpty ? [median] : members)
        }
        guard !blocks.isEmpty else { throw URLError(.cannotParseResponse) }
        return KpForecast(source: .gfz, blocks: blocks)
    }

    /// NOAA's JSON: objects with "time_tag" (UTC, no zone suffix) and "kp", covering a week back and 3 days ahead.
    static func parseNOAA(_ data: Data) throws -> KpForecast {
        struct Row: Decodable {
            let time_tag: String
            let kp: Double
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let earliest = Date().addingTimeInterval(-3 * 3600)
        let blocks = try JSONDecoder().decode([Row].self, from: data).compactMap { row -> KpForecast.Block? in
            guard let start = formatter.date(from: row.time_tag), start >= earliest else { return nil }
            return KpForecast.Block(start: start, median: row.kp, members: [row.kp])
        }
        guard !blocks.isEmpty else { throw URLError(.cannotParseResponse) }
        return KpForecast(source: .noaa, blocks: blocks)
    }
}

/// Where and when aurora might be seen from one place, from the Kp forecast, darkness and cloud.
struct AuroraOutlook {
    enum Level: Int, Comparable {
        case low, possible, good, strong

        var name: String {
            switch self {
            case .low: "Low"
            case .possible: "Possible"
            case .good: "Good"
            case .strong: "Strong"
            }
        }

        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }

        init(chance: Double) {
            switch chance {
            case 0.5...: self = .strong
            case 0.25...: self = .good
            case 0.08...: self = .possible
            default: self = .low
            }
        }
    }

    /// Why tonight's chance is what it is, in the order the card mentions it.
    enum Limit {
        case none, tooLight, cloud, quiet
    }

    let kpNeeded: Double
    /// 0...1 for the best hour tonight, after darkness and cloud.
    let chance: Double
    let level: Level
    let bestWindow: DateInterval?
    let limit: Limit
    /// Cloud cover in the best hour, when the forecast reaches it.
    let cloud: Double?

    /// Below this geomagnetic latitude even a severe storm rarely reaches the horizon, so the card stays hidden.
    static let minimumLatitude = 49.0

    /// Geomagnetic latitude from the IGRF-14 dipole (north geomagnetic pole 80.8° N, 72.6° W, epoch 2025).
    static func geomagneticLatitude(latitude: Double, longitude: Double) -> Double {
        let poleLat = 80.8 * Double.pi / 180
        let poleLon = -72.6 * Double.pi / 180
        let lat = latitude * .pi / 180
        let lon = longitude * .pi / 180
        let sine = sin(lat) * sin(poleLat) + cos(lat) * cos(poleLat) * cos(lon - poleLon)
        return asin(min(max(sine, -1), 1)) * 180 / .pi
    }

    /// Kp at which the oval's glow reaches this place's horizon: about 66.5° at Kp 0, two degrees further per step.
    static func kpNeeded(geomagneticLatitude: Double) -> Double {
        min(max((66.5 - abs(geomagneticLatitude)) / 2, 0), 9)
    }

    static func shows(latitude: Double, longitude: Double) -> Bool {
        abs(geomagneticLatitude(latitude: latitude, longitude: longitude)) >= minimumLatitude
    }

    /// Chance one Kp value brings aurora into view, eased so a forecast one step short still counts a little.
    static func stormChance(kp: Double, needed: Double) -> Double {
        min(max(0.5 + (kp - needed) * 0.35, 0), 0.95)
    }

    static func stormChance(_ block: KpForecast.Block, needed: Double) -> Double {
        block.members.map { stormChance(kp: $0, needed: needed) }.reduce(0, +) / Double(block.members.count)
    }

    /// Dark enough when the sun is 12° below the horizon (nautical twilight's end).
    static func isDark(at date: Date, latitude: Double, longitude: Double) -> Bool {
        Solar.elevation(at: date, latitude: latitude, longitude: longitude) < -12
    }

    /// Tonight is the next run of dark hours within a day; each hour's chance is the storm chance times clear sky.
    init(forecast: KpForecast, latitude: Double, longitude: Double, cloudCover: [Date: Double], now: Date = .now) {
        let needed = Self.kpNeeded(geomagneticLatitude: Self.geomagneticLatitude(latitude: latitude, longitude: longitude))
        kpNeeded = needed
        let startHour = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / 3600).rounded(.down) * 3600)

        var night: [(date: Date, storm: Double, cloud: Double?)] = []
        for step in 0..<24 {
            let hour = startHour.addingTimeInterval(Double(step) * 3600)
            let middle = hour.addingTimeInterval(1800)
            if Self.isDark(at: middle, latitude: latitude, longitude: longitude) {
                let storm = forecast.block(at: middle).map { Self.stormChance($0, needed: needed) } ?? 0
                night.append((hour, storm, cloudCover[hour]))
            } else if !night.isEmpty {
                break
            }
        }

        guard let best = night.max(by: { $0.storm * (1 - ($0.cloud ?? 0)) < $1.storm * (1 - ($1.cloud ?? 0)) }) else {
            chance = 0
            level = .low
            bestWindow = nil
            limit = .tooLight
            cloud = nil
            return
        }
        let bestChance = best.storm * (1 - (best.cloud ?? 0))
        chance = bestChance
        level = Level(chance: bestChance)
        cloud = best.cloud
        // The window spans the dark hours whose chance is close to the best.
        let close = night.filter { $0.storm * (1 - ($0.cloud ?? 0)) >= bestChance * 0.8 && bestChance > 0 }
        if let first = close.first, let last = close.last {
            bestWindow = DateInterval(start: first.date, end: last.date.addingTimeInterval(3600))
        } else {
            bestWindow = nil
        }
        if best.storm < 0.08 {
            limit = .quiet
        } else if let cloud = best.cloud, cloud >= 0.6 {
            limit = .cloud
        } else {
            limit = .none
        }
    }
}
