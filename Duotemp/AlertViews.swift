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

/// The detail screen's alerts in one card that stays small: the most severe, and how many others. With one
/// alert, tapping opens the agency's full warning; with more, the card expands to list each.
struct AlertBanner: View {
    let alerts: [ActiveAlert]

    @State private var expanded = false

    var body: some View {
        let distinct = alerts.bySeverity
        if let first = distinct.first {
            VStack(alignment: .leading, spacing: 0) {
                if distinct.count == 1 {
                    Link(destination: first.detailsURL) {
                        row(first, detail: details(first), trailing: "arrow.up.right")
                    }
                    .accessibilityHint("Opens the full warning from \(first.source)")
                } else {
                    Button {
                        withAnimation(.snappy) { expanded.toggle() }
                    } label: {
                        row(first, detail: "and \(distinct.count - 1) more", trailing: expanded ? "chevron.up" : "chevron.down")
                    }
                    .accessibilityHint(expanded ? "Hides the list" : "Lists every alert")
                    if expanded {
                        ForEach(distinct, id: \.self) { alert in
                            Divider().overlay(SkyStyle.secondary.opacity(0.4))
                            Link(destination: alert.detailsURL) {
                                row(alert, detail: details(alert), trailing: "arrow.up.right")
                            }
                            .accessibilityHint("Opens the full warning from \(alert.source)")
                        }
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(RoundedRectangle(cornerRadius: 20))
        }
    }

    private func row(_ alert: ActiveAlert, detail: String, trailing: String) -> some View {
        HStack(spacing: 12) {
            AlertBadge(severity: alert.severity)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.summary)
                    .font(.headline)
                    .lineLimit(2)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(SkyStyle.secondary)
                    .lineLimit(1)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: trailing)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SkyStyle.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func details(_ alert: ActiveAlert) -> String {
        [alert.severity.label, alert.region, alert.source].compactMap { $0 }.joined(separator: " · ")
    }
}
