import Foundation

/// An active warning from a national weather service, as WeatherKit reports it. WeatherKit gives no
/// start or end time; the agency's page at `detailsURL` has them.
struct ActiveAlert: Codable, Hashable, Sendable {
    enum Severity: String, Codable, Comparable, Sendable {
        case unknown, minor, moderate, severe, extreme

        private var rank: Int {
            switch self {
            case .unknown: 0
            case .minor: 1
            case .moderate: 2
            case .severe: 3
            case .extreme: 4
            }
        }

        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rank < rhs.rank }
    }

    let summary: String
    let region: String?
    /// The issuing agency.
    let source: String
    let severity: Severity
    /// The agency's full warning; Apple requires it to be shown unaltered.
    let detailsURL: URL
}

extension [ActiveAlert] {
    /// Most severe first, with exact repeats dropped: WeatherKit can return one copy of a warning per area
    /// with nothing else to tell them apart.
    var bySeverity: [ActiveAlert] {
        var seen = Set<[String]>()
        return sorted { $0.severity > $1.severity }.filter { alert in
            seen.insert([alert.summary, alert.severity.rawValue, alert.source, alert.region ?? ""]).inserted
        }
    }
}
