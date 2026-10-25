import SwiftUI

struct LocationDetailView: View {
    let target: DetailTarget
    let model: LocationsModel
    /// Hands each loaded forecast up, so the pager can credit its sources in a bar that spans every page.
    var onLoad: (ForecastDetail) -> Void = { _ in }

    @State private var detail: ForecastDetail?
    @State private var errorMessage: String?
    @State private var kp: KpForecast?
    @State private var kpFailed = false

    private var lead: LeadUnit { model.lead }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let snapshot = detail?.snapshot ?? model.snapshots[target.key] {
                    if let alerts = snapshot.alerts, !alerts.isEmpty {
                        AlertBanner(alerts: alerts)
                    }
                    header(snapshot)
                }
                if let detail {
                    hourlyCard(detail)
                    dailyCard(detail)
                    if AuroraOutlook.shows(latitude: target.latitude, longitude: target.longitude, forecast: kp) {
                        AuroraCard(forecast: kp, failed: kpFailed, detail: detail, latitude: target.latitude, longitude: target.longitude)
                    }
                    conditionsGrid(detail)
                } else if let errorMessage {
                    ContentUnavailableView("Forecast unavailable", systemImage: "icloud.slash", description: Text(errorMessage))
                } else {
                    ProgressView()
                        .padding(.top, 40)
                }
            }
            .padding(16)
        }
        .defaultScrollAnchor(Self.startAnchor)
        .foregroundStyle(.white)
        .environment(\.rainIntensity, currentHour.flatMap { RainIntensity(symbolName: $0.symbolName) })
        .environment(\.rainSlant, currentHour.map { SkyScene.slant(windSpeed: $0.windSpeed, from: $0.windFromDirection) } ?? -0.15)
        .task { await load() }
        .refreshable { await load() }
    }

    /// Screenshots: `-scrollAnchor 0.6` opens the screen that far down (0 top, 1 bottom). Always the top in release builds.
    private static var startAnchor: UnitPoint {
        #if DEBUG
        if let fraction = UserDefaults.standard.object(forKey: "scrollAnchor") as? String, let y = Double(fraction) {
            return UnitPoint(x: 0.5, y: y)
        }
        #endif
        return .top
    }

    private var currentHour: WeatherSnapshot.Hour? {
        (detail?.snapshot ?? model.snapshots[target.key])?.now(at: .now)
    }

    private func load() async {
        async let aurora: Void = loadAurora()
        do {
            let loaded = try await model.detail(for: target)
            detail = loaded
            onLoad(loaded)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        await aurora
    }

    /// Only fetched where the card can show; a failure leaves the rest of the screen alone.
    private func loadAurora() async {
        guard AuroraOutlook.mayShow(latitude: target.latitude, longitude: target.longitude) else { return }
        do {
            kp = try await AuroraClient.forecast()
            kpFailed = false
        } catch {
            kpFailed = kp == nil
        }
    }

    // MARK: - Sections

    private func header(_ snapshot: WeatherSnapshot) -> some View {
        let now = snapshot.now(at: .now)
        return VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                TemperatureText(temperature: now.temperature, unit: lead, size: 64)
                TemperatureText(temperature: now.temperature, unit: lead.other, size: 34)
                    .foregroundStyle(SkyStyle.secondary)
            }
            HStack(spacing: 6) {
                WeatherSymbol(name: now.symbolName, size: 18)
                Text(now.condition)
            }
            .font(.title3.weight(.semibold))
            Text("Feels \(now.feelsLike.pair(lead: lead))")
                .font(.headline)
            Text("H \(snapshot.high.pair(lead: lead))   L \(snapshot.low.pair(lead: lead))")
                .font(.subheadline)
                .foregroundStyle(SkyStyle.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .skyTextShadow()
    }

    private func hourlyCard(_ detail: ForecastDetail) -> some View {
        let timeZone = detail.snapshot.timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        // 24 hours here; the rest of the 48 fetched feed the aurora card, and the 10-day card covers later days.
        return Card(title: "Next 24 hours") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(Array(detail.hours.prefix(24).enumerated()), id: \.element.id) { index, hour in
                        // Midnight shows the new day's name, after a divider, so it's clear where tomorrow starts.
                        let newDay = index > 0 && calendar.component(.hour, from: hour.date) == 0
                        if newDay {
                            Rectangle()
                                .fill(SkyStyle.secondary.opacity(0.4))
                                .frame(width: 1)
                                .padding(.vertical, 2)
                        }
                        VStack(spacing: 6) {
                            Text(index == 0 ? "Now" : hour.date.formatted(newDay ? weekdayStyle(timeZone) : hourStyle(timeZone)))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(newDay ? .white : SkyStyle.secondary)
                            WeatherSymbol(name: hour.symbolName, size: 20)
                                .frame(height: 24)
                            Text(hour.temperature.degrees(lead))
                                .font(.headline)
                            Text(hour.temperature.degrees(lead.other))
                                .font(.subheadline)
                                .foregroundStyle(SkyStyle.secondary)
                            RainLabel(chance: hour.precipitationChance, millimetres: hour.precipitationMM, lead: lead)
                        }
                        .frame(minWidth: 40)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        // Rain meets only the top card, so it stays a hint rather than covering the screen.
        .rainSplashes()
    }

    private func dailyCard(_ detail: ForecastDetail) -> some View {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = detail.snapshot.timeZone
        return Card(title: "\(detail.days.count)-day forecast") {
            VStack(spacing: 0) {
                ForEach(Array(detail.days.enumerated()), id: \.element.id) { index, day in
                    if index > 0 { Divider().overlay(SkyStyle.secondary.opacity(0.2)) }
                    HStack(spacing: 10) {
                        Text(calendar.isDateInToday(day.date) ? "Today" : day.date.formatted(weekdayStyle(detail.snapshot.timeZone)))
                            .font(.body.weight(.semibold))
                            .frame(width: 56, alignment: .leading)
                        WeatherSymbol(name: day.symbolName, size: 18)
                            .frame(width: 28)
                        RainLabel(chance: day.precipitationChance, millimetres: day.precipitationMM, lead: lead, compact: true)
                            .frame(width: 64, alignment: .leading)
                        Spacer(minLength: 0)
                        Text("L \(day.low.compactPair(lead: lead))")
                            .foregroundStyle(SkyStyle.secondary)
                        Text("H \(day.high.compactPair(lead: lead))")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func conditionsGrid(_ detail: ForecastDetail) -> some View {
        let c = detail.conditions
        let timeZone = detail.snapshot.timeZone
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            if let speed = c.windSpeed {
                ConditionTile(title: "Wind", symbol: "wind", value: Units.wind(speed, lead: lead), caption: windCaption(c)) {
                    WindCompass(
                        direction: c.windDirection,
                        speed: "\(Int((speed * (lead == .celsius ? 3.6 : 2.23694)).rounded()))",
                        unit: lead == .celsius ? "km/h" : "mph"
                    )
                }
            }
            if let humidity = c.humidity {
                ConditionTile(title: "Humidity", symbol: "humidity", value: Units.percent(humidity), caption: c.dewPoint.map { "Dew point \($0.pair(lead: lead))" }) {
                    HumidityRing(fraction: humidity)
                }
            }
            if let uv = c.uvIndex {
                ConditionTile(title: "UV index", symbol: "sun.max", value: uvAdvice(uv), caption: detail.sources[.uv] == .yr ? "Clear-sky maximum" : nil) {
                    UVScale(index: uv)
                }
            }
            if let pressure = c.pressure {
                ConditionTile(title: "Pressure", symbol: "gauge.with.dots.needle.50percent", value: Units.pressure(pressure, lead: lead)) {
                    PressureDial(hectopascals: pressure, trend: c.pressureTrend)
                }
            }
            if let visibility = c.visibility {
                ConditionTile(title: "Visibility", symbol: "eye", value: Units.visibility(visibility, lead: lead)) {
                    VisibilityScale(metres: visibility)
                }
            }
            if c.sunrise != nil || c.sunset != nil {
                ConditionTile(
                    title: "Sun",
                    symbol: "sunrise",
                    value: "↑ \(c.sunrise.map { $0.formatted(timeStyle(timeZone)) } ?? "—")   ↓ \(c.sunset.map { $0.formatted(timeStyle(timeZone)) } ?? "—")",
                    caption: daylightCaption(c)
                ) {
                    DaylightArc(sunrise: c.sunrise, sunset: c.sunset, now: .now, timeZone: timeZone)
                }
            }
        }
    }

    private func windCaption(_ c: ForecastDetail.Conditions) -> String? {
        var parts: [String] = []
        if let direction = c.windDirection { parts.append("From \(Units.compass(direction))") }
        if let gust = c.windGust { parts.append("Gusts \(Units.wind(gust, lead: lead))") }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    private func uvAdvice(_ index: Int) -> String {
        index >= 3 ? "Sun protection advised" : "No protection needed"
    }

    private func daylightCaption(_ c: ForecastDetail.Conditions) -> String? {
        guard let sunrise = c.sunrise, let sunset = c.sunset, sunset > sunrise else { return nil }
        let minutes = Int(sunset.timeIntervalSince(sunrise) / 60)
        return "\(minutes / 60)h \(minutes % 60)m of daylight"
    }

    // MARK: - Formatting in the location's time zone

    private func hourStyle(_ timeZone: TimeZone) -> Date.FormatStyle {
        var style = Date.FormatStyle.dateTime.hour()
        style.timeZone = timeZone
        return style
    }

    private func weekdayStyle(_ timeZone: TimeZone) -> Date.FormatStyle {
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated)
        style.timeZone = timeZone
        return style
    }

    private func timeStyle(_ timeZone: TimeZone) -> Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return style
    }
}

// MARK: - Pieces

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(SkyStyle.secondary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(RoundedRectangle(cornerRadius: 20))
    }
}

/// Chance of rain when known, else the amount; hidden when it's dry.
private struct RainLabel: View {
    let chance: Double?
    let millimetres: Double?
    let lead: LeadUnit
    var compact = false

    private static let rainBlue = Color(hex: 0x8FC3E8)

    var body: some View {
        VStack(spacing: 2) {
            if let chance, chance >= 0.1 {
                Text(Units.percent(chance))
            }
            if let millimetres, millimetres >= 0.1, !(compact && (chance ?? 0) >= 0.1) {
                Text(Units.rain(millimetres, lead: lead))
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Self.rainBlue)
        .frame(minHeight: compact ? nil : 28, alignment: .top)
    }
}
