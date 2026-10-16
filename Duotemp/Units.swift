import Foundation

/// Dual-unit text for the detail screen; the lead unit's system comes first.
enum Units {
    static func wind(_ metresPerSecond: Double, lead: LeadUnit) -> String {
        let kmh = "\(Int((metresPerSecond * 3.6).rounded())) km/h"
        let mph = "\(Int((metresPerSecond * 2.23694).rounded())) mph"
        return lead == .celsius ? "\(kmh) · \(mph)" : "\(mph) · \(kmh)"
    }

    static func pressure(_ hectopascals: Double, lead: LeadUnit) -> String {
        let hPa = "\(Int(hectopascals.rounded())) hPa"
        let inHg = String(format: "%.2f inHg", hectopascals * 0.02953)
        return lead == .celsius ? "\(hPa) · \(inHg)" : "\(inHg) · \(hPa)"
    }

    static func visibility(_ metres: Double, lead: LeadUnit) -> String {
        let km = "\(Int((metres / 1000).rounded())) km"
        let mi = "\(Int((metres / 1609.34).rounded())) mi"
        return lead == .celsius ? "\(km) · \(mi)" : "\(mi) · \(km)"
    }

    /// Rain follows the lead unit's system: millimetres with °C, inches with °F.
    static func rain(_ millimetres: Double, lead: LeadUnit) -> String {
        lead == .celsius ? String(format: "%.1f mm", millimetres) : String(format: "%.2f in", millimetres / 25.4)
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// Compass point the wind blows from.
    static func compass(_ degrees: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360 + 22.5) / 45).rounded(.down)) % 8
        return points[index]
    }
}
