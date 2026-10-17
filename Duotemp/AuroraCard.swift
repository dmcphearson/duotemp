import SwiftUI

/// The chance of seeing the northern (or southern) lights tonight and on the next nights the forecast covers.
struct AuroraCard: View {
    let forecast: KpForecast?
    let failed: Bool
    let detail: ForecastDetail
    let latitude: Double
    let longitude: Double

    static let green = Color(hex: 0x6CEBA6)
    /// A night this likely opens the full card on its own; below it the card stays one line until tapped.
    static let expandChance = 0.5

    @State private var expanded = false

    private var timeZone: TimeZone { detail.snapshot.timeZone }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let forecast {
                let outlook = AuroraOutlook(forecast: forecast, latitude: latitude, longitude: longitude, cloudCover: cloudCover)
                let later = AuroraOutlook.laterNights(
                    after: outlook, forecast: forecast, latitude: latitude, longitude: longitude, cloudCover: cloudCover
                )
                let nights = [outlook.asNight].compactMap { $0 } + later
                let automatic = nights.contains { $0.chance >= Self.expandChance }
                if automatic || expanded {
                    header(collapsible: !automatic)
                    summary(outlook)
                    VStack(spacing: 8) {
                        ForEach(Array(nights.enumerated()), id: \.element.start) { index, night in
                            NightRow(name: index == 0 && outlook.asNight != nil ? "Tonight" : night.start.formatted(weekdayStyle),
                                     night: night, timeZone: timeZone)
                        }
                    }
                    Link(forecast.source.credit, destination: forecast.source.url)
                        .font(.caption2)
                        .foregroundStyle(SkyStyle.secondary)
                } else {
                    compact(outlook)
                }
            } else {
                header(collapsible: false)
                if failed {
                    Text("Aurora forecast unavailable. Pull to retry.")
                        .font(.subheadline)
                        .foregroundStyle(SkyStyle.secondary)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(RoundedRectangle(cornerRadius: 20))
    }

    private var title: String { latitude < 0 ? "SOUTHERN LIGHTS" : "NORTHERN LIGHTS" }

    /// The card's title; when the card was opened by a tap, tapping it folds the card again.
    @ViewBuilder
    private func header(collapsible: Bool) -> some View {
        let label = Label(title, systemImage: "sparkles")
            .font(.caption.weight(.semibold))
            .foregroundStyle(SkyStyle.secondary)
        if collapsible {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { expanded = false }
            } label: {
                HStack {
                    label
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SkyStyle.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows less")
        } else {
            label
        }
    }

    /// Under 50% on every night: one line with tonight's level, which opens the full card when tapped.
    private func compact(_ outlook: AuroraOutlook) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { expanded = true }
        } label: {
            HStack(spacing: 8) {
                Label(title, systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SkyStyle.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(outlook.limit == .tooLight ? "Too light tonight" : "\(outlook.level.name) · \(Int((outlook.chance * 100).rounded()))% tonight")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(outlook.level >= .possible ? Self.green : .white)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SkyStyle.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows the next nights")
    }

    private var cloudCover: [Date: Double] {
        Dictionary(detail.hours.compactMap { hour in hour.cloudCover.map { (hour.date, $0) } }, uniquingKeysWith: { first, _ in first })
    }

    private func summary(_ outlook: AuroraOutlook) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(outlook.level.name)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(outlook.level >= .possible ? Self.green : .white)
                if outlook.limit != .tooLight {
                    Text("\(Int((outlook.chance * 100).rounded()))% tonight")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SkyStyle.secondary)
                }
            }
            // The best time sits in tonight's row; this line only explains a night that won't work.
            if outlook.limit != .none {
                Text(reason(outlook))
                    .font(.subheadline)
            }
            // Under the oval itself any activity will do, so a threshold of 0 isn't worth stating.
            Text(outlook.kpNeeded < 1 ? "Under the auroral oval: any clear, dark night" : "Needs Kp \(Self.kpText(outlook.kpNeeded)) or more here")
                .font(.caption)
                .foregroundStyle(SkyStyle.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func reason(_ outlook: AuroraOutlook) -> String {
        switch outlook.limit {
        case .tooLight:
            return "Not dark enough tonight"
        case .quiet:
            return "Activity too low to reach this far"
        case .cloud:
            return "Cloud may hide it (\(Units.percent(outlook.cloud ?? 0)) cover)"
        case .none:
            guard let window = outlook.bestWindow else { return "Watch after dark" }
            var style = Date.FormatStyle(date: .omitted, time: .shortened)
            style.timeZone = timeZone
            return "Best \(window.start.formatted(style)) to \(window.end.formatted(style))"
        }
    }

    private var weekdayStyle: Date.FormatStyle {
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated)
        style.timeZone = timeZone
        return style
    }

    static func kpText(_ kp: Double) -> String {
        kp.rounded() == kp ? "\(Int(kp))" : String(format: "%.1f", kp)
    }
}

/// One night: a meter of its best chance, the percentage, and its best window.
private struct NightRow: View {
    let name: String
    let night: AuroraOutlook.Night
    let timeZone: TimeZone

    private var percent: Int { Int((night.chance * 100).rounded()) }

    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .frame(width: 64, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(AuroraOutlook.Level(chance: night.chance) >= .possible ? AuroraCard.green : .white.opacity(0.5))
                        .frame(width: night.chance > 0 ? max(6, proxy.size.width * night.chance) : 0)
                }
            }
            .frame(height: 6)
            Text("\(percent)%")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(width: 40, alignment: .trailing)
            Text(windowText)
                .font(.caption)
                .foregroundStyle(SkyStyle.secondary)
                .frame(width: 92, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): \(percent) percent\(windowText == "—" ? "" : ", best \(windowText)")")
    }

    private var windowText: String {
        // Below "Possible" every hour is about as unlikely as the next, so a window would mean little.
        guard let window = night.window, AuroraOutlook.Level(chance: night.chance) >= .possible else { return "—" }
        var style = Date.FormatStyle.dateTime.hour()
        style.timeZone = timeZone
        return "\(window.start.formatted(style))–\(window.end.formatted(style))"
    }
}
