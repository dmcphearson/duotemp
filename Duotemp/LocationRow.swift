import SwiftUI

struct LocationRow: View {
    let name: String
    let tag: String?
    let snapshot: WeatherSnapshot?
    let failed: Bool
    let lead: LeadUnit
    var failureText = "Weather unavailable. Pull to retry."

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.title3.weight(.semibold))
                if let tag {
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                if let snapshot {
                    details(snapshot)
                } else if failed {
                    Text(failureText)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            Spacer(minLength: 8)
            if let snapshot {
                let temperature = snapshot.now(at: .now).temperature
                VStack(alignment: .trailing, spacing: 2) {
                    TemperatureText(temperature: temperature, unit: lead, size: 38)
                    TemperatureText(temperature: temperature, unit: lead.other, size: 22)
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func details(_ snapshot: WeatherSnapshot) -> some View {
        let now = snapshot.now(at: .now)
        HStack(spacing: 5) {
            WeatherSymbol(name: now.symbolName, size: 14)
            Text(now.condition)
        }
        .font(.subheadline)
        .foregroundStyle(Theme.secondary)
        Text("Feels \(now.feelsLike.pair(lead: lead))")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.accent)
        Text("H \(snapshot.high.pair(lead: lead))  L \(snapshot.low.pair(lead: lead))")
            .font(.caption)
            .foregroundStyle(Theme.secondary)
        Text("\(failed ? "Couldn't refresh · " : "")Updated \(snapshot.fetchedAt, format: .dateTime.hour().minute())")
            .font(.caption2)
            .foregroundStyle(Theme.secondary)
    }
}
