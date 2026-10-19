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
    /// Reports the open space between the name and the temperatures, in the card's content coordinates,
    /// so the sky behind can fit its moon there whatever the text size, weight or name length.
    var moonSpace: Binding<CGRect?> = .constant(nil)

    /// The row insets every card uses; the sky behind spans them, so it offsets `moonSpace` by these.
    static let insets = EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
    nonisolated private static let space = "LocationRow"

    @State private var nameFrame: CGRect?
    @State private var temperatureFrame: CGRect?

    private var openSpace: CGRect? {
        guard let nameFrame, let temperatureFrame, temperatureFrame.minX > nameFrame.maxX else { return nil }
        return CGRect(
            x: nameFrame.maxX, y: temperatureFrame.minY,
            width: temperatureFrame.minX - nameFrame.maxX, height: temperatureFrame.height
        )
    }

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
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { nameFrame = $0 }
                Spacer(minLength: 8)
                if let snapshot {
                    let temperature = snapshot.now(at: .now).temperature
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TemperatureText(temperature: temperature, unit: lead.other, size: 20)
                            .foregroundStyle(SkyStyle.secondary)
                        TemperatureText(temperature: temperature, unit: lead, size: 44)
                    }
                    .lineLimit(1)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { temperatureFrame = $0 }
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
        .coordinateSpace(.named(Self.space))
        .onChange(of: openSpace, initial: true) { moonSpace.wrappedValue = openSpace }
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
    static func background(for snapshot: WeatherSnapshot?, moonSpace: CGRect?) -> some View {
        RowSky(snapshot: snapshot, moonSpace: moonSpace)
    }
}

private struct RowSky: View {
    let snapshot: WeatherSnapshot?
    let moonSpace: CGRect?
    @AppStorage(SkyAnimation.storageKey) private var animation = SkyAnimation.everywhere

    var body: some View {
        if let snapshot {
            let now = snapshot.now(at: .now)
            GeometryReader { proxy in
                let moon = Self.moon(in: moonSpace, size: proxy.size)
                SkyScene(
                    hour: now, next: snapshot.hour(after: now), place: snapshot.placeName,
                    moonAnchor: moon?.anchor, moonScale: moon?.scale ?? 1, showsMoon: moon != nil,
                    animated: animation.animatesList
                )
            }
        } else {
            Theme.card
        }
    }

    /// Centres a slightly smaller moon in the space between the name and the temperatures, shrinking it to
    /// keep a margin from the text, and leaves it out when larger or bolder text or a long name closes the gap.
    private static func moon(in space: CGRect?, size: CGSize) -> (anchor: UnitPoint, scale: CGFloat)? {
        guard let space, size.width > 0, size.height > 0 else { return nil }
        let full = SkyScene.moonRadius(size: min(size.width, size.height))
        let margin: CGFloat = 10
        let radius = min(full * 0.85, (space.width - 2 * margin) / 2)
        guard radius >= full * 0.55 else { return nil }
        let center = CGPoint(x: space.midX + LocationRow.insets.leading, y: space.midY + LocationRow.insets.top)
        return (UnitPoint(x: center.x / size.width, y: center.y / size.height), radius / full)
    }
}
