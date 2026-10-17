import SwiftUI

/// The detail screen's condition tiles: a small graphic for each reading with both unit systems beside it.
struct ConditionTile<Graphic: View>: View {
    let title: String
    let symbol: String
    let value: String
    var caption: String?
    @ViewBuilder let graphic: Graphic

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title.uppercased(), systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SkyStyle.secondary)
            graphic
                .frame(maxWidth: .infinity, minHeight: 78)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(SkyStyle.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 196, alignment: .topLeading)
        .glassPanel(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Wind

/// Compass rose with an arrow pointing where the wind blows to, and the lead-unit speed in the middle.
struct WindCompass: View {
    /// Degrees the wind blows from.
    let direction: Double?
    let speed: String
    let unit: String

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.18), lineWidth: 1)
            ForEach(0..<36) { tick in
                Capsule()
                    .fill(.white.opacity(tick % 9 == 0 ? 0.8 : 0.3))
                    .frame(width: 1.2, height: tick % 9 == 0 ? 7 : 4)
                    .offset(y: -36)
                    .rotationEffect(.degrees(Double(tick) * 10))
            }
            ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { index, letter in
                Text(letter)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(SkyStyle.secondary)
                    .offset(y: -26)
                    .rotationEffect(.degrees(Double(index) * 90))
            }
            if let direction {
                WindArrow()
                    .fill(.white)
                    .frame(width: 10, height: 76)
                    .rotationEffect(.degrees(direction + 180))
            }
            VStack(spacing: -2) {
                Text(speed).font(.system(size: 17, weight: .bold))
                Text(unit).font(.system(size: 8, weight: .semibold)).foregroundStyle(SkyStyle.secondary)
            }
            .padding(6)
            .glassPanel(Circle())
        }
        .frame(width: 80, height: 80)
    }
}

/// A thin shaft with a head at the top and a tail at the bottom.
private struct WindArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midX
        path.move(to: CGPoint(x: mid, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 10))
        path.addLine(to: CGPoint(x: mid + 1, y: rect.minY + 8))
        path.addLine(to: CGPoint(x: mid + 1, y: rect.maxY - 2))
        path.addArc(center: CGPoint(x: mid, y: rect.maxY - 2), radius: 2, startAngle: .zero, endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: mid - 1, y: rect.minY + 8))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 10))
        path.closeSubpath()
        return path
    }
}

// MARK: - Humidity

/// Ring filled to the relative humidity.
struct HumidityRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.15), lineWidth: 9)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(
                    AngularGradient(colors: [Color(hex: 0x8FC3E8), Color(hex: 0x4F8FD9)], center: .center),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: "drop.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: 0x8FC3E8))
        }
        .frame(width: 72, height: 72)
    }
}

// MARK: - UV

enum UVLevel {
    static func name(_ index: Int) -> String {
        switch index {
        case ..<3: "Low"
        case 3..<6: "Moderate"
        case 6..<8: "High"
        case 8..<11: "Very high"
        default: "Extreme"
        }
    }
}

/// WHO colour scale from 0 to 11+ with a marker at the index.
struct UVScale: View {
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(index)").font(.system(size: 38, weight: .semibold))
                Text(UVLevel.name(index)).font(.headline)
            }
            GeometryReader { geometry in
                let x = geometry.size.width * min(Double(index), 11) / 11
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [0x4CB848, 0xF2D02B, 0xF28C28, 0xE53B2F, 0x9B4FB0].map { Color(hex: $0) },
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: 6)
                    Circle()
                        .fill(.white)
                        .overlay(Circle().stroke(.black.opacity(0.3), lineWidth: 1))
                        .frame(width: 11, height: 11)
                        .offset(x: min(max(x - 5.5, 0), geometry.size.width - 11))
                }
            }
            .frame(height: 11)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Pressure

/// Half dial from 960 to 1060 hPa with a needle and the trend.
struct PressureDial: View {
    let hectopascals: Double
    let trend: ForecastDetail.PressureTrend?

    private static let range = 960.0...1060.0

    var body: some View {
        let span = Self.range.upperBound - Self.range.lowerBound
        let fraction = (min(max(hectopascals, Self.range.lowerBound), Self.range.upperBound) - Self.range.lowerBound) / span
        ZStack(alignment: .bottom) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height - 4)
                let radius = min(size.width / 2, size.height) - 6
                for tick in 0...40 {
                    let angle = Double.pi * (1 - Double(tick) / 40)
                    let major = tick % 10 == 0
                    let inner = radius - (major ? 9 : 5)
                    var path = Path()
                    path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y - sin(angle) * inner))
                    path.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y - sin(angle) * radius))
                    context.stroke(path, with: .color(.white.opacity(major ? 0.7 : 0.3)), lineWidth: major ? 1.5 : 1)
                }
                let angle = Double.pi * (1 - fraction)
                var needle = Path()
                needle.move(to: center)
                needle.addLine(to: CGPoint(x: center.x + cos(angle) * (radius - 4), y: center.y - sin(angle) * (radius - 4)))
                context.stroke(needle, with: .color(.white), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(.white))
            }
            .frame(width: 120, height: 66)
            if let trend {
                Label(trendText(trend), systemImage: trendSymbol(trend))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SkyStyle.secondary)
                    .offset(y: 14)
            }
        }
        .padding(.bottom, trend == nil ? 0 : 14)
    }

    private func trendText(_ trend: ForecastDetail.PressureTrend) -> String {
        switch trend {
        case .rising: "Rising"
        case .steady: "Steady"
        case .falling: "Falling"
        }
    }

    private func trendSymbol(_ trend: ForecastDetail.PressureTrend) -> String {
        switch trend {
        case .rising: "arrow.up.right"
        case .steady: "arrow.right"
        case .falling: "arrow.down.right"
        }
    }
}

// MARK: - Visibility

enum VisibilityLevel {
    static func name(_ metres: Double) -> String {
        switch metres {
        case ..<1000: "Fog"
        case ..<4000: "Poor"
        case ..<10000: "Moderate"
        case ..<20000: "Good"
        default: "Excellent"
        }
    }
}

/// Distance on a log scale from 100 m to 40 km, fading from fog grey to clear.
struct VisibilityScale: View {
    let metres: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(VisibilityLevel.name(metres)).font(.title3.weight(.semibold))
            GeometryReader { geometry in
                let low = log10(100.0), high = log10(40000.0)
                let fraction = (log10(min(max(metres, 100), 40000)) - low) / (high - low)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(0.15), .white.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 6)
                    Image(systemName: "eye.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(3)
                        .glassPanel(Circle())
                        .offset(x: min(max(geometry.size.width * fraction - 10, 0), geometry.size.width - 20))
                }
            }
            .frame(height: 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Sun

/// The sun's path over the local day as a wave, the horizon where it crosses at sunrise and sunset,
/// and a dot for now.
struct DaylightArc: View {
    let sunrise: Date?
    let sunset: Date?
    let now: Date
    let timeZone: TimeZone

    var body: some View {
        Canvas { context, size in
            guard let sunrise, let sunset, sunset > sunrise else { return }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let dayStart = calendar.startOfDay(for: sunrise)
            let day = 24.0 * 3600
            let noon = sunrise.addingTimeInterval(sunset.timeIntervalSince(sunrise) / 2)
            let horizon = cos(Double.pi * sunset.timeIntervalSince(sunrise) / day)

            let amplitude = size.height / 2 - 6
            func point(_ seconds: Double) -> CGPoint {
                let phase = 2 * Double.pi * (dayStart.addingTimeInterval(seconds).timeIntervalSince(noon)) / day
                return CGPoint(x: size.width * seconds / day, y: size.height / 2 - cos(phase) * amplitude)
            }
            let horizonY = size.height / 2 - horizon * amplitude

            var wave = Path()
            for step in 0...96 {
                let p = point(Double(step) / 96 * day)
                step == 0 ? wave.move(to: p) : wave.addLine(to: p)
            }
            // Below the horizon dim, above it bright.
            context.drawLayer { layer in
                layer.clip(to: Path(CGRect(x: 0, y: horizonY, width: size.width, height: size.height)))
                layer.stroke(wave, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
            }
            context.drawLayer { layer in
                layer.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: horizonY)))
                var fill = wave
                fill.addLine(to: CGPoint(x: size.width, y: horizonY))
                fill.addLine(to: CGPoint(x: 0, y: horizonY))
                fill.closeSubpath()
                layer.fill(fill, with: .linearGradient(
                    Gradient(colors: [Theme.accent.opacity(0.35), Theme.accent.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: horizonY)
                ))
                layer.stroke(wave, with: .color(Theme.accent), lineWidth: 2)
            }
            var line = Path()
            line.move(to: CGPoint(x: 0, y: horizonY))
            line.addLine(to: CGPoint(x: size.width, y: horizonY))
            context.stroke(line, with: .color(.white.opacity(0.35)), lineWidth: 1)

            let seconds = min(max(now.timeIntervalSince(dayStart), 0), day)
            let sun = point(seconds)
            let isUp = now > sunrise && now < sunset
            context.fill(Path(ellipseIn: CGRect(x: sun.x - 9, y: sun.y - 9, width: 18, height: 18)), with: .color((isUp ? Theme.accent : .white).opacity(0.25)))
            context.fill(Path(ellipseIn: CGRect(x: sun.x - 5, y: sun.y - 5, width: 10, height: 10)), with: .color(isUp ? Color(hex: 0xFFE3A3) : .white.opacity(0.8)))
        }
        .frame(height: 70)
    }
}
