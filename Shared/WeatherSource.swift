import Foundation

/// Where forecasts come from. Yr is the default; Apple Weather is the alternative.
enum WeatherSource: String, Codable, CaseIterable, Sendable {
    case yr
    case apple

    var displayName: String {
        switch self {
        case .yr: "Yr (MET Norway)"
        case .apple: "Apple Weather"
        }
    }

    /// Who to credit for data from this source.
    var creditName: String {
        switch self {
        case .yr: "MET Norway"
        case .apple: "Apple Weather"
        }
    }
}
