import SwiftUI

/// Tonight's chance of seeing the northern (or southern) lights, with the next three days of Kp behind it.
struct AuroraCard: View {
    let forecast: KpForecast?
    let failed: Bool
    let detail: ForecastDetail
    let latitude: Double
    let longitude: Double

    static let green = Color(hex: 0x6CEBA6)

    private var timeZone: TimeZone { detail.snapshot.timeZone }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(latitude < 0 ? "SOUTHERN LIGHTS" : "NORTHERN LIGHTS", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SkyStyle.secondary)
            if let forecast {
                let outlook = AuroraOutlook(forecast: forecast, latitude: latitude, longitude: longitude, cloudCover: cloudCover)
                summary(outlook)
                KpChart(forecast: forecast, needed: outlook.kpNeeded, latitude: latitude, longitude: longitude, timeZone: timeZone)
                Link(forecast.source.credit, destination: forecast.source.url)
                    .font(.caption2)
                    .foregroundStyle(SkyStyle.secondary)
            } else if failed {
                Text("Aurora forecast unavailable. Pull to retry.")
                    .font(.subheadline)
                    .foregroundStyle(SkyStyle.secondary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(RoundedRectangle(cornerRadius: 20))
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
            Text(reason(outlook))
                .font(.subheadline)
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

    static func kpText(_ kp: Double) -> String {
        kp.rounded() == kp ? "\(Int(kp))" : String(format: "%.1f", kp)
    }
}

/// One bar per 3-hour block, green where Kp reaches what this place needs; night blocks are shaded.
private struct KpChart: View {
    let forecast: KpForecast
    let needed: Double
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone

    private static let height: CGFloat = 64

    private var blocks: [KpForecast.Block] {
        let now = Date()
        return Array(forecast.blocks.filter { $0.start.addingTimeInterval(3 * 3600) > now }.prefix(24))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(blocks, id: \.start) { block in
                    let middle = block.start.addingTimeInterval(5400)
                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(.white.opacity(AuroraOutlook.isDark(at: middle, latitude: latitude, longitude: longitude) ? 0.08 : 0))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(block.median >= needed ? AuroraCard.green : .white.opacity(0.45))
                            .frame(height: max(2, Self.height * block.median / 9))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: Self.height)
            .overlay(alignment: .bottom) {
                // The level this place needs, dashed across the bars; the summary above names it.
                Line()
                    .stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)
                    .offset(y: -Self.height * needed / 9)
            }
            // Each day's label sits under the first block of that local day.
            HStack(spacing: 2) {
                ForEach(Array(blocks.enumerated()), id: \.element.start) { index, block in
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: 14)
                        .overlay(alignment: .leading) {
                            if let day = dayStart(at: index) {
                                Text(day.formatted(weekdayStyle))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(SkyStyle.secondary)
                                    .fixedSize()
                            }
                        }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Kp forecast for the next three days; peak Kp \(AuroraCard.kpText(blocks.map(\.median).max() ?? 0))")
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }

    private var weekdayStyle: Date.FormatStyle {
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated)
        style.timeZone = timeZone
        return style
    }

    /// The local day starting at this block, when it's the first block of that day with room for a label.
    private func dayStart(at index: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.startOfDay(for: blocks[index].start)
        let isNewDay = index == 0 ? false : calendar.startOfDay(for: blocks[index - 1].start) != day
        return isNewDay && blocks.count - index >= 3 ? day : nil
    }
}
