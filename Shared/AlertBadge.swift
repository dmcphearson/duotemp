import SwiftUI

extension ActiveAlert.Severity {
    /// Warning colours as European agencies issue them: yellow for moderate and below, orange for severe, red for extreme.
    var color: Color {
        switch self {
        case .unknown, .minor, .moderate: .yellow
        case .severe: .orange
        case .extreme: .red
        }
    }

    var label: String? {
        switch self {
        case .unknown: nil
        case .minor: "Minor"
        case .moderate: "Moderate"
        case .severe: "Severe"
        case .extreme: "Extreme"
        }
    }
}

/// A warning triangle in the alert's colour.
struct AlertBadge: View {
    let severity: ActiveAlert.Severity

    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.black, severity.color)
            .accessibilityLabel([severity.label, "weather alert"].compactMap { $0 }.joined(separator: " "))
    }
}
