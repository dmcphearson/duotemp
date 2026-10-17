import SwiftUI

/// A location card: name and subtitle with the dual temperature on top, condition and feels-like with
/// high and low below, on the sky for the current hour.
struct LocationRow: View {
    let name: String
    /// "My Location", or nil to show the place's local time when it differs from here.
    let tag: String?
    let snapshot: WeatherSnapshot?
    let failed: Bool
    let lead: LeadUnit
    var failureText = "Weather unavailable. Pull to retry."

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    subtitle
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SkyStyle.secondary)
                }
                Spacer(minLength: 8)
                if let snapshot {
                    let temperature = snapshot.now(at: .now).temperature
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TemperatureText(temperature: temperature, unit: lead.other, size: 20)
                            .foregroundStyle(SkyStyle.secondary)
                        TemperatureText(temperature: temperature, unit: lead, size: 44)
                    }
                    .lineLimit(1)
                }
            }
            Spacer(minLength: 14)
            if let snapshot {
                footer(snapshot)
            } else if failed {
                Text(failureText)
                    .font(.subheadline)
                    .foregroundStyle(SkyStyle.secondary)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 104)
        .foregroundStyle(.white)
        .skyTextShadow()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var subtitle: some View {
        if let tag {
            HStack(spacing: 4) {
                Image(systemName: "location.fill").imageScale(.small)
                Text(tag)
            }
        } else if let snapshot, snapshot.timeZone.identifier != TimeZone.current.identifier {
            TimelineView(.everyMinute) { context in
                // Text(_:format:) swaps in the device's time zone, so format to a string first.
                Text(context.date.formatted(Self.timeStyle(snapshot.timeZone)))
            }
        }
    }

    private func footer(_ snapshot: WeatherSnapshot) -> some View {
        let now = snapshot.now(at: .now)
        return HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    WeatherSymbol(name: now.symbolName, size: 14)
                    Text(now.condition)
                }
                .font(.subheadline.weight(.medium))
                Text("Feels \(now.feelsLike.pair(lead: lead))")
                    .font(.footnote.weight(.semibold))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if failed {
                    Text("Couldn't refresh")
                        .font(.caption2)
                        .foregroundStyle(SkyStyle.secondary)
                }
                Text("H \(snapshot.high.compactPair(lead: lead))  L \(snapshot.low.compactPair(lead: lead))")
                    .font(.footnote.weight(.semibold))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    private static func timeStyle(_ timeZone: TimeZone) -> Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return style
    }

    /// The sky for the current hour, matching the widget; the plain card until weather loads.
    /// Apply with `listRowBackground` on the row, since row traits don't pass through a NavigationLink's label.
    @ViewBuilder
    static func background(for snapshot: WeatherSnapshot?) -> some View {
        if let snapshot {
            // The moon sits in the open middle, between the name and the temperature.
            SkyScene(hour: snapshot.now(at: .now), place: snapshot.placeName, moonAnchor: UnitPoint(x: 0.55, y: 0.3), animated: true)
        } else {
            Theme.card
        }
    }
}
