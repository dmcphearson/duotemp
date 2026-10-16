import Foundation

/// Which scale is shown first and largest; the other is always shown beside it.
enum LeadUnit: String, Codable, CaseIterable, Sendable {
    case celsius = "C"
    case fahrenheit = "F"

    var other: LeadUnit { self == .celsius ? .fahrenheit : .celsius }
}

/// A temperature in both scales. Each scale is rounded from the source value on its own,
/// so 17.6 °C shows as 18° / 64° rather than converting an already-rounded number.
struct DualTemp: Codable, Hashable, Sendable {
    let celsius: Double

    init(celsius: Double) {
        self.celsius = celsius
    }

    init(_ measurement: Measurement<UnitTemperature>) {
        celsius = measurement.converted(to: .celsius).value
    }

    func value(in unit: LeadUnit) -> Int {
        switch unit {
        case .celsius: Int(celsius.rounded())
        case .fahrenheit: Int((celsius * 9 / 5 + 32).rounded())
        }
    }

    /// "18°"
    func degrees(_ unit: LeadUnit) -> String {
        "\(value(in: unit))°"
    }

    /// "18°C"
    func labelled(_ unit: LeadUnit) -> String {
        degrees(unit) + unit.rawValue
    }

    /// "18° / 64°", lead unit first.
    func pair(lead: LeadUnit) -> String {
        "\(degrees(lead)) / \(degrees(lead.other))"
    }

    /// "18°/64°", for tight widget rows.
    func compactPair(lead: LeadUnit) -> String {
        "\(degrees(lead))/\(degrees(lead.other))"
    }

    /// "18°C / 64°F"
    func labelledPair(lead: LeadUnit) -> String {
        "\(labelled(lead)) / \(labelled(lead.other))"
    }
}
