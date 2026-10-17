import SwiftUI
import WidgetKit

struct WeatherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeatherEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            let now = snapshot.now(at: entry.date)
            switch family {
            case .systemMedium:
                MediumView(entry: entry, snapshot: snapshot, now: now)
            case .accessoryRectangular:
                RectangularView(entry: entry, snapshot: snapshot, now: now)
            case .accessoryCircular:
                CircularView(lead: entry.lead, now: now)
            case .accessoryInline:
                Label("\(now.temperature.labelledPair(lead: entry.lead)) · Feels \(now.feelsLike.degrees(entry.lead))", systemImage: now.symbolName)
                    .symbolVariant(.fill)
            default:
                SmallView(entry: entry, snapshot: snapshot, now: now)
            }
        } else {
            UnavailableView(isCurrentLocation: entry.isCurrentLocation)
        }
    }
}

/// Home Screen widgets take the sky for the hour on screen; Lock Screen widgets use the system's.
struct WidgetBackground: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeatherEntry

    var body: some View {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
            if let snapshot = entry.snapshot {
                // Clear of the text: the medium widget's top-right holds the conditions, so its sun and moon
                // sit top-centre; the small widget's moon sits right of the condition line.
                let now = snapshot.now(at: entry.date)
                SkyScene(
                    hour: now,
                    next: snapshot.hour(after: now),
                    place: snapshot.placeName,
                    celestial: family == .systemMedium ? UnitPoint(x: 0.56, y: 0.08) : UnitPoint(x: 0.95, y: 0.04),
                    moonAnchor: family == .systemSmall ? UnitPoint(x: 0.84, y: 0.67) : nil,
                    sunFollowsTime: false,
                    date: entry.date
                )
            } else {
                Theme.card
            }
        case .accessoryCircular: AccessoryWidgetBackground()
        default: Color.clear
        }
    }
}

// MARK: - Home Screen

private struct SmallView: View {
    let entry: WeatherEntry
    let snapshot: WeatherSnapshot
    let now: WeatherSnapshot.Hour

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlaceName(name: snapshot.placeName, isCurrent: entry.isCurrentLocation)
            Spacer(minLength: 0)
            BigTemps(temperature: now.temperature, lead: entry.lead)
            Spacer(minLength: 0)
            ConditionLabel(hour: now)
            FeelsLike(temperature: now.feelsLike, lead: entry.lead)
                .padding(.top, 1)
            HighLow(snapshot: snapshot, lead: entry.lead)
        }
        .foregroundStyle(.white)
    }
}

private struct MediumView: View {
    let entry: WeatherEntry
    let snapshot: WeatherSnapshot
    let now: WeatherSnapshot.Hour

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    PlaceName(name: snapshot.placeName, isCurrent: entry.isCurrentLocation)
                    BigTemps(temperature: now.temperature, lead: entry.lead, leadSize: 40, trailSize: 24)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    ConditionLabel(hour: now)
                    HighLow(snapshot: snapshot, lead: entry.lead)
                    FeelsLike(temperature: now.feelsLike, lead: entry.lead)
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 0) {
                ForEach(snapshot.upcoming(after: entry.date), id: \.date) { hour in
                    HourColumn(hour: hour, lead: entry.lead, timeZone: snapshot.timeZone)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .foregroundStyle(.white)
    }
}

private struct HourColumn: View {
    let hour: WeatherSnapshot.Hour
    let lead: LeadUnit
    let timeZone: TimeZone

    var body: some View {
        VStack(spacing: 3) {
            // Text(_:format:) swaps in the device's time zone, so format to a string first.
            Text(hour.date.formatted(Self.hourStyle(timeZone)))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SkyStyle.secondary)
            WeatherSymbol(name: hour.symbolName, size: 18)
                .frame(height: 22)
            Text(hour.temperature.degrees(lead))
                .font(.system(size: 15, weight: .semibold))
            Text(hour.temperature.degrees(lead.other))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SkyStyle.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// Locale-appropriate hour ("22" in Ireland, "10 PM" in the US) in the location's time zone.
    private static func hourStyle(_ timeZone: TimeZone) -> Date.FormatStyle {
        var style = Date.FormatStyle.dateTime.hour()
        style.timeZone = timeZone
        return style
    }
}

// MARK: - Lock Screen

private struct RectangularView: View {
    let entry: WeatherEntry
    let snapshot: WeatherSnapshot
    let now: WeatherSnapshot.Hour

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 3) {
                if entry.isCurrentLocation {
                    Image(systemName: "location.fill").font(.system(size: 9, weight: .semibold))
                }
                Text(snapshot.placeName).font(.headline).lineLimit(1)
            }
            Text(now.temperature.labelledPair(lead: entry.lead))
                .font(.system(size: 20, weight: .semibold))
            Text("Feels \(now.feelsLike.compactPair(lead: entry.lead))")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CircularView: View {
    let lead: LeadUnit
    let now: WeatherSnapshot.Hour

    var body: some View {
        VStack(spacing: 0) {
            Text(now.temperature.labelled(lead))
                .font(.system(size: 17, weight: .bold))
            Text(now.temperature.labelled(lead.other))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .minimumScaleFactor(0.7)
        .widgetAccentable()
    }
}

// MARK: - Pieces

private struct PlaceName: View {
    let name: String
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if isCurrent {
                Image(systemName: "location.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .accessibilityLabel("Current location")
            }
        }
    }
}

private struct BigTemps: View {
    let temperature: DualTemp
    let lead: LeadUnit
    var leadSize: CGFloat = 42
    var trailSize: CGFloat = 26

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            TemperatureText(temperature: temperature, unit: lead, size: leadSize)
            TemperatureText(temperature: temperature, unit: lead.other, size: trailSize)
                .foregroundStyle(SkyStyle.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct ConditionLabel: View {
    let hour: WeatherSnapshot.Hour
    var size: CGFloat = 12

    var body: some View {
        // The symbol gets a fixed slot sized to the text, so the line's text and edges line up with the lines below.
        HStack(spacing: 4) {
            WeatherSymbol(name: hour.symbolName, size: size)
                .frame(width: size + 4, height: size + 2, alignment: .leading)
            Text(hour.condition)
                .font(.system(size: size, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct FeelsLike: View {
    let temperature: DualTemp
    let lead: LeadUnit

    var body: some View {
        Text("Feels \(temperature.pair(lead: lead))")
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
    }
}

private struct HighLow: View {
    let snapshot: WeatherSnapshot
    let lead: LeadUnit

    var body: some View {
        Text("H \(snapshot.high.compactPair(lead: lead))  L \(snapshot.low.compactPair(lead: lead))")
            .font(.system(size: 12))
            .foregroundStyle(SkyStyle.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct UnavailableView: View {
    let isCurrentLocation: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: isCurrentLocation ? "location.slash" : "icloud.slash")
                .font(.title3)
            Text(isCurrentLocation ? "Open duoTemp Weather to allow location" : "Weather unavailable")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Theme.secondary)
    }
}
