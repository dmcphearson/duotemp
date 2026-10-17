import SwiftUI

/// Where storm flashes light up: anywhere in the upper sky, or inside the drawn clouds, moving between them.
enum LightningStyle: String, CaseIterable {
    case anywhere, clouds

    static let storageKey = "lightningStyle"
}

/// A drawn sky: the SkyStyle gradient plus sun, moon and stars, clouds, rain, snow, fog or lightning.
/// Still by default, for widgets; `animated` adds gentle motion in the app, and Reduce Motion turns it off.
/// Between forecast hours the sun's height is interpolated, so sunrise, sunset and twilight build
/// gradually and the day sky blends into the night one. Rain and snow lean with the hour's wind.
/// Stars and clouds are placed from a seed derived from the place name, so a location keeps the same
/// sky between refreshes.
struct SkyScene: View {
    let symbolName: String
    let isDaylight: Bool?
    let track: SunTrack
    let moonPhase: Double
    let seed: UInt64
    /// Where the moon sits, and the sun when it doesn't follow the time of day, as a fraction of the size.
    let celestial: UnitPoint
    /// Overrides the moon's place, unclamped, for layouts whose free space isn't near the top.
    let moonAnchor: UnitPoint?
    let sunFollowsTime: Bool
    let animated: Bool
    /// The moment a still sky shows; widgets pass their entry's date, since iOS may draw entries ahead of time.
    let date: Date?
    /// Sideways drift per point of fall, from the wind; negative leans left.
    let slant: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(LightningStyle.storageKey) private var lightningStyle = LightningStyle.clouds

    /// With `sunFollowsTime`, the sun rises at the left edge and sets at the right; widgets turn it off
    /// and keep the sun at `celestial`, clear of their text. Pass the forecast hour after `hour` as `next`
    /// so the sky can blend between the two.
    init(
        hour: WeatherSnapshot.Hour,
        next: WeatherSnapshot.Hour? = nil,
        place: String,
        celestial: UnitPoint = UnitPoint(x: 0.95, y: 0.04),
        moonAnchor: UnitPoint? = nil,
        sunFollowsTime: Bool = true,
        animated: Bool = false,
        date: Date? = nil
    ) {
        self.date = date
        self.celestial = celestial
        self.moonAnchor = moonAnchor
        self.sunFollowsTime = sunFollowsTime
        self.animated = animated
        moonPhase = Lunar.phase(at: hour.date)
        symbolName = hour.symbolName
        isDaylight = hour.isDaylight
        track = SunTrack(hour: hour, next: next)
        slant = Self.slant(windSpeed: hour.windSpeed, from: hour.windFromDirection)
        seed = place.utf8.reduce(0xCBF2_9CE4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01B3 }
    }

    /// Rain drifts with the wind's east-west component: a westerly pushes it right, an easterly left,
    /// calm air lets it fall straight. Unknown wind keeps a slight lean.
    static func slant(windSpeed: Double?, from direction: Double?) -> CGFloat {
        guard let windSpeed, let direction else { return -0.15 }
        let eastward = -sin(direction * .pi / 180) * min(windSpeed, 15) / 15
        return CGFloat(eastward * 0.6)
    }

    /// Two layers so slow things don't redraw at the rain's rate: the sky, sun, moon, stars, clouds and
    /// fog at 12 frames a second, and lightning, rain and snow at 30, only when there are any.
    var body: some View {
        ZStack {
            layer(weather: false, interval: 1.0 / 12)
            if hasWeather {
                layer(weather: true, interval: 1.0 / 30)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var hasWeather: Bool {
        Decor(symbolName: symbolName, glow: 0, moonPhase: 0, daylight: 1, slant: 0).hasWeather
    }

    @ViewBuilder
    private func layer(weather: Bool, interval: Double) -> some View {
        if animated && !reduceMotion {
            TimelineView(.animation(minimumInterval: interval)) { timeline in
                frame(weather: weather, at: timeline.date, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else if animated {
            TimelineView(.everyMinute) { timeline in
                frame(weather: weather, at: timeline.date, time: nil)
            }
        } else {
            frame(weather: weather, at: date ?? .now, time: nil)
        }
    }

    private func frame(weather: Bool, at date: Date, time: Double?) -> some View {
        let sky = track.at(date)
        let style = SkyStyle(symbolName: symbolName, isDaylight: isDaylight)
        // 1 by day, 0 by night, blending from 4° above the horizon to 6° below as dusk ends.
        let daylight = sky.elevation.map { min(max(($0 + 6) / 10, 0), 1) } ?? (isDaylight == false ? 0 : 1)
        let glow = style.glow(sunElevation: sky.elevation)
        var decor = Decor(symbolName: symbolName, glow: glow, moonPhase: moonPhase, daylight: daylight, slant: slant)
        // Both layers place clouds from this, so lightning can find the clouds the backdrop drew.
        decor.cloudSeed = seed ^ 0xC10D_C10D_C10D_C10D
        decor.lightningStyle = lightningStyle
        let seed = weather ? seed ^ 0x5EED_5EED_5EED_5EED : seed
        let celestial = celestial
        let moonAnchor = moonAnchor
        let progress = sunFollowsTime ? sky.progress : nil
        return Canvas { context, size in
            var random = SeededRandom(state: seed)
            if weather {
                decor.drawWeather(in: &context, size: size, time: time, random: &random)
            } else {
                decor.drawBackdrop(
                    in: &context, size: size, celestial: celestial, moonAnchor: moonAnchor,
                    sunProgress: progress, time: time, random: &random
                )
            }
        }
        .background {
            if !weather {
                style.gradient(daylight: daylight, glow: glow)
            }
        }
    }
}

/// The sun's height and day progress at any moment, interpolated between two forecast hours.
struct SunTrack: Sendable {
    let start: Date
    let end: Date?
    let elevations: (Double?, Double?)
    let progresses: (Double?, Double?)

    init(hour: WeatherSnapshot.Hour, next: WeatherSnapshot.Hour?) {
        start = hour.date
        end = next?.date
        elevations = (hour.sunElevation, next?.sunElevation)
        progresses = (hour.sunProgress, next?.sunProgress)
    }

    func at(_ date: Date) -> (elevation: Double?, progress: Double?) {
        guard let end, end > start else { return (elevations.0, progresses.0) }
        let t = min(max(date.timeIntervalSince(start) / end.timeIntervalSince(start), 0), 1)
        let elevation: Double? = switch elevations {
        case let (a?, b?): a + (b - a) * t
        case let (a, b): a ?? b
        }
        // Across sunrise or sunset one end has no progress: the sun is heading for the left or right edge.
        let progress: Double? = switch progresses {
        case let (a?, b?): a + (b - a) * t
        case let (a?, nil): a + (1 - a) * t
        case let (nil, b?): b * t
        case (nil, nil): nil
        }
        return (elevation, progress)
    }
}

private struct Decor {
    enum RainAmount { case drizzle, rain, heavy }
    enum Precipitation { case rain(RainAmount), snow(heavy: Bool) }

    var sun = false
    var moon = false
    var stars = false
    var clouds = 0
    var fog = false
    var storm = false
    /// Sunrise or sunset strength, 0...1; warms the sun.
    var glow = 0.0
    /// 0 new, 0.5 full; see `Lunar`.
    var moonPhase = 0.0
    /// 1 by day, 0 by night; the sun fades out and the moon and stars fade in between.
    var daylight = 1.0
    var slant: CGFloat = 0
    var precipitation: Precipitation?
    var cloudSeed: UInt64 = 0
    var lightningStyle = LightningStyle.clouds

    init(symbolName: String, glow: Double, moonPhase: Double, daylight: Double, slant: CGFloat) {
        self.glow = glow
        self.moonPhase = moonPhase
        self.daylight = daylight
        self.slant = slant
        let parts = Set(symbolName.split(separator: ".").map(String.init))
        // Clear and partly cloudy skies show the sun by day and the moon and stars by night.
        let clear = parts.contains("sun") || parts.contains("moon")
        sun = clear && daylight > 0.01
        moon = clear && daylight < 0.99
        stars = moon
        fog = !parts.isDisjoint(with: ["fog", "haze", "smoke", "dust"])
        storm = parts.contains("bolt")
        if !parts.isDisjoint(with: ["snow", "sleet", "hail", "snowflake"]) {
            precipitation = .snow(heavy: parts.contains("snowflake") || parts.contains("wind"))
        } else if !parts.isDisjoint(with: ["rain", "drizzle", "heavyrain", "bolt"]) {
            precipitation = .rain(
                parts.contains("heavyrain") || parts.contains("bolt") ? .heavy : (parts.contains("drizzle") ? .drizzle : .rain)
            )
        }
        if fog {
            clouds = 0
        } else if parts.contains("cloud") {
            clouds = clear ? 2 : 4
        }
    }

    var hasWeather: Bool { storm || precipitation != nil }

    /// Sun, moon, stars, fog and clouds: the slow-moving part.
    func drawBackdrop(
        in context: inout GraphicsContext,
        size: CGSize,
        celestial: UnitPoint,
        moonAnchor: UnitPoint?,
        sunProgress: Double?,
        time: Double?,
        random: inout SeededRandom
    ) {
        let unit = min(size.width, size.height)
        let anchor = CGPoint(x: celestial.x * size.width, y: celestial.y * size.height)
        let moonCenter: CGPoint? = if !moon {
            nil
        } else if let moonAnchor {
            CGPoint(x: moonAnchor.x * size.width, y: moonAnchor.y * size.height)
        } else {
            // Keep the whole moon on screen.
            CGPoint(x: min(max(anchor.x, unit * 0.18), size.width - unit * 0.18), y: max(anchor.y, unit * 0.16))
        }
        if stars {
            // No stars inside the moon's disc, where its dark part would let them show through.
            context.drawLayer { layer in
                layer.opacity = 1 - daylight
                if let moonCenter {
                    layer.clip(to: circle(moonCenter, moonRadius(unit) + 1), options: .inverse)
                }
                drawStars(in: &layer, size: size, time: time, random: &random)
            }
        }
        if sun {
            context.drawLayer { layer in
                layer.opacity = daylight
                drawSun(in: &layer, at: sunProgress.map { sunPosition(progress: $0, size: size, unit: unit) } ?? anchor, unit: unit, time: time)
            }
        }
        if let moonCenter {
            context.drawLayer { layer in
                layer.opacity = 1 - daylight
                drawMoon(in: &layer, at: moonCenter, unit: unit, time: time)
            }
        }
        if fog {
            let sunAt = sunProgress.map { sunPosition(progress: $0, size: size, unit: unit) } ?? anchor
            drawFog(in: &context, size: size, unit: unit, sunAt: sunAt, time: time, random: &random)
        }
        drawClouds(in: &context, size: size, unit: unit, time: time)
    }

    /// Lightning, rain and snow: the fast-moving part.
    func drawWeather(in context: inout GraphicsContext, size: CGSize, time: Double?, random: inout SeededRandom) {
        let unit = min(size.width, size.height)
        if storm { drawLightning(in: &context, size: size, unit: unit, time: time, random: &random) }
        switch precipitation {
        case .rain(let amount): drawRain(in: &context, size: size, unit: unit, amount: amount, time: time, random: &random)
        case .snow(let heavy): drawSnow(in: &context, size: size, heavy: heavy, time: time, random: &random)
        case nil: break
        }
    }

    /// A slow sine between -1 and 1, or 0 when still.
    private func wave(_ time: Double?, period: Double, phase: Double) -> Double {
        guard let time else { return 0 }
        return sin(2 * .pi * (time / period + phase))
    }

    /// Wraps `value` into `start ..< start + span`, for things that fall off the bottom and re-enter at the top.
    private func wrapped(_ value: CGFloat, from start: CGFloat, span: CGFloat) -> CGFloat {
        let offset = (value - start).truncatingRemainder(dividingBy: span)
        return start + (offset < 0 ? offset + span : offset)
    }

    /// Along an arc: rising at the left edge, highest at solar noon, setting at the right edge.
    private func sunPosition(progress: Double, size: CGSize, unit: CGFloat) -> CGPoint {
        let height = sin(progress * .pi)
        return CGPoint(x: size.width * progress, y: unit * (0.02 + 0.2 * (1 - height)))
    }

    /// Warm glow with faint halo bands. Animated, each band fades in and out on its own slow cycle,
    /// so together they shimmer without a visible pattern.
    private func drawSun(in context: inout GraphicsContext, at center: CGPoint, unit: CGFloat, time: Double?) {
        let radius = unit * 1.05
        context.fill(
            circle(center, radius),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color.white.mix(with: Color(hex: 0xFFC27A), by: glow).opacity(0.6), location: 0),
                    .init(color: Theme.accent.opacity(0.22 + 0.25 * glow), location: 0.28),
                    .init(color: .clear, location: 1),
                ]),
                center: center, startRadius: 0, endRadius: radius
            )
        )
        let bands: [(fraction: Double, period: Double, phase: Double)] = [(0.3, 9.4, 0.12), (0.5, 12.6, 0.62), (0.74, 17.8, 0.27), (0.94, 22.6, 0.84)]
        for band in bands {
            let opacity = time == nil ? 0.08 : 0.065 + 0.05 * wave(time, period: band.period, phase: band.phase)
            context.stroke(circle(center, radius * band.fraction), with: .color(.white.opacity(opacity)), lineWidth: 1)
        }
        softEllipse(
            &context, CGRect(x: center.x - unit * 0.13, y: center.y - unit * 0.13, width: unit * 0.26, height: unit * 0.26),
            color: Color.white.mix(with: Color(hex: 0xFFD49A), by: glow), opacity: 0.8, solid: 0.5
        )
    }

    private func moonRadius(_ unit: CGFloat) -> CGFloat {
        min(unit * 0.1, 20)
    }

    /// The moon at its phase with a cool glow: lit on the right while waxing, on the left while waning,
    /// with the dark part faintly visible.
    private func drawMoon(in context: inout GraphicsContext, at center: CGPoint, unit: CGFloat, time: Double?) {
        let radius = moonRadius(unit)
        let breath = wave(time, period: 14, phase: 0)
        let glowRadius = radius * (6 + 0.4 * breath)
        context.fill(
            circle(center, glowRadius),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.16 + 0.04 * breath), .clear]),
                center: center, startRadius: 0, endRadius: glowRadius
            )
        )
        context.fill(circle(center, radius), with: .color(.white.opacity(0.1)))
        // The terminator is a half-ellipse whose width follows cos(phase); the lit limb is a half-circle.
        let side: CGFloat = moonPhase < 0.5 ? 1 : -1
        let squash = CGFloat(cos(2 * Double.pi * moonPhase))
        var lit = Path()
        for step in 0...32 {
            let y = -radius + 2 * radius * CGFloat(step) / 32
            let half = (radius * radius - y * y).squareRoot()
            let point = CGPoint(x: center.x + side * half, y: center.y + y)
            step == 0 ? lit.move(to: point) : lit.addLine(to: point)
        }
        for step in stride(from: 32, through: 0, by: -1) {
            let y = -radius + 2 * radius * CGFloat(step) / 32
            let half = (radius * radius - y * y).squareRoot()
            lit.addLine(to: CGPoint(x: center.x + side * half * squash, y: center.y + y))
        }
        lit.closeSubpath()
        context.fill(lit, with: .color(.white.opacity(0.92)))
    }

    private func drawStars(in context: inout GraphicsContext, size: CGSize, time: Double?, random: inout SeededRandom) {
        let count = Int(min(size.width * size.height / 1800, 240))
        for index in 0..<count {
            let point = CGPoint(x: .random(in: 0...size.width, using: &random), y: .random(in: 0...size.height * 0.9, using: &random))
            let radius = CGFloat.random(in: 0.4...1.3, using: &random)
            let twinkle = wave(time, period: .random(in: 2.5...6, using: &random), phase: .random(in: 0...1, using: &random))
            let opacity = Double.random(in: 0.25...0.85, using: &random) * (1 + 0.4 * twinkle)
            context.fill(circle(point, radius), with: .color(.white.opacity(min(opacity, 1))))
            if index % 40 == 0 {
                // An occasional four-point sparkle.
                var sparkle = Path()
                sparkle.move(to: CGPoint(x: point.x - 4, y: point.y))
                sparkle.addLine(to: CGPoint(x: point.x + 4, y: point.y))
                sparkle.move(to: CGPoint(x: point.x, y: point.y - 4))
                sparkle.addLine(to: CGPoint(x: point.x, y: point.y + 4))
                context.stroke(sparkle, with: .color(.white.opacity(0.5)), lineWidth: 0.6)
            }
        }
    }

    /// Soft layered clouds: a flat base with three puffs, blurred.
    /// Each cloud's base line (`x`, `y`) and width, drifting with `time`; seeded on its own so the
    /// lightning layer gets the same clouds as the backdrop.
    private func cloudLayout(size: CGSize, unit: CGFloat, time: Double?) -> [(x: CGFloat, y: CGFloat, width: CGFloat)] {
        var random = SeededRandom(state: cloudSeed)
        return (0..<clouds).map { _ in
            let width = min(size.width * .random(in: 0.45...0.75, using: &random), unit * 1.6)
            let drift = wave(time, period: .random(in: 60...92, using: &random), phase: .random(in: 0...1, using: &random))
            let x = CGFloat.random(in: -width * 0.3...size.width - width * 0.5, using: &random) + width * 0.07 * drift
            // Within the top of a tall sky, so the full-screen sky keeps its clouds overhead rather than behind the cards.
            let y = min(size.height, unit * 1.2) * .random(in: 0.08...0.6, using: &random)
            return (x, y, width)
        }
    }

    private func drawClouds(in context: inout GraphicsContext, size: CGSize, unit: CGFloat, time: Double?) {
        guard clouds > 0 else { return }
        let dayOpacity = clouds > 2 ? 0.12 : 0.16
        let opacity = 0.07 + (dayOpacity - 0.07) * daylight
        for (x, y, width) in cloudLayout(size: size, unit: unit, time: time) {
            // One blurred shape keeps the cloud even; soft-edged parts would build up where they overlap.
            var cloud = Path()
            cloud.addRoundedRect(in: CGRect(x: x, y: y, width: width, height: width * 0.22), cornerSize: CGSize(width: width * 0.11, height: width * 0.11))
            cloud.addEllipse(in: CGRect(x: x + width * 0.1, y: y - width * 0.14, width: width * 0.34, height: width * 0.34))
            cloud.addEllipse(in: CGRect(x: x + width * 0.32, y: y - width * 0.26, width: width * 0.46, height: width * 0.46))
            cloud.addEllipse(in: CGRect(x: x + width * 0.62, y: y - width * 0.1, width: width * 0.3, height: width * 0.3))
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: width * 0.035))
                layer.fill(cloud, with: .color(.white.opacity(opacity)))
            }
        }
    }

    /// Slanted streaks; drizzle is sparse, short, faint and slow, heavy rain dense and fast.
    private func drawRain(in context: inout GraphicsContext, size: CGSize, unit: CGFloat, amount: RainAmount, time: Double?, random: inout SeededRandom) {
        let (areaPerDrop, lengths, maxLength, speed, opacity): (CGFloat, ClosedRange<CGFloat>, CGFloat, CGFloat, Double) = switch amount {
        case .drizzle: (2400, 0.02...0.04, 8, 140, 0.15)
        case .rain: (800, 0.04...0.08, 16, 240, 0.2)
        case .heavy: (450, 0.04...0.08, 16, 340, 0.28)
        }
        let count = Int(min(size.width * size.height / areaPerDrop, 600))
        var streaks = Path()
        for _ in 0..<count {
            let length = min(unit * .random(in: lengths, using: &random), maxLength)
            var start = CGPoint(x: .random(in: 0...size.width + 10, using: &random), y: .random(in: -10...size.height, using: &random))
            let pace = CGFloat.random(in: 0.85...1.15, using: &random)
            if let time {
                // Falls along the streak's slant and re-enters at the top.
                let fall = CGFloat(time.truncatingRemainder(dividingBy: 600)) * speed * pace
                start.y = wrapped(start.y + fall, from: -20, span: size.height + 20)
                start.x = wrapped(start.x + fall * slant, from: -10, span: size.width + 20)
            }
            streaks.move(to: start)
            streaks.addLine(to: CGPoint(x: start.x + length * slant, y: start.y + length))
        }
        context.stroke(streaks, with: .color(.white.opacity(opacity)), style: StrokeStyle(lineWidth: amount == .drizzle ? 0.75 : 1, lineCap: .round))
    }

    /// Flakes that sway and drift with the wind. Heavy snow is dense, bigger and faster, with a whiteout
    /// haze building toward the ground.
    private func drawSnow(in context: inout GraphicsContext, size: CGSize, heavy: Bool, time: Double?, random: inout SeededRandom) {
        if heavy {
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.03), .white.opacity(0.16)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }
        let count = Int(min(size.width * size.height / (heavy ? 380 : 900), heavy ? 700 : 400))
        let sizes: ClosedRange<CGFloat> = heavy ? 1.2...3 : 1...2.4
        var flakes = Path()
        for _ in 0..<count {
            var point = CGPoint(x: .random(in: 0...size.width, using: &random), y: .random(in: 0...size.height, using: &random))
            let radius = CGFloat.random(in: sizes, using: &random)
            let sway = wave(time, period: .random(in: 3...5, using: &random), phase: .random(in: 0...1, using: &random))
            if let time {
                // Bigger flakes fall a little faster.
                let fall = CGFloat(time.truncatingRemainder(dividingBy: 3600)) * (14 + 10 * radius) * (heavy ? 1.5 : 1)
                point.y = wrapped(point.y + fall, from: -4, span: size.height + 8)
                point.x = wrapped(point.x + fall * slant * 0.8 + 4 * sway, from: -4, span: size.width + 8)
            }
            flakes.addPath(circle(point, radius))
        }
        context.fill(flakes, with: .color(.white.opacity(heavy ? 0.7 : 0.55)))
    }

    /// Layered haze: by day a pale sun disc shows through, then three depths of very soft bands drift at
    /// different speeds, thickening toward the ground.
    private func drawFog(in context: inout GraphicsContext, size: CGSize, unit: CGFloat, sunAt: CGPoint, time: Double?, random: inout SeededRandom) {
        if daylight > 0 {
            // Where the sun would be, kept just inside the frame and blurred, as if seen through fog.
            let center = CGPoint(x: min(max(sunAt.x, unit * 0.15), size.width - unit * 0.15), y: max(sunAt.y, unit * 0.15))
            context.fill(
                circle(center, unit * 0.45),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.22 * daylight), .white.opacity(0.06 * daylight), .clear]),
                    center: center, startRadius: 0, endRadius: unit * 0.45
                )
            )
            softEllipse(
                &context, CGRect(x: center.x - unit * 0.115, y: center.y - unit * 0.115, width: unit * 0.23, height: unit * 0.23),
                opacity: 0.28 * daylight, solid: 0.4
            )
        }
        // Back to front: wide and faint high up, tighter and brighter low down.
        let layers: [(top: CGFloat, height: CGFloat, blur: CGFloat, opacity: Double, period: ClosedRange<Double>)] = [
            (0.15, 0.3, 0.14, 0.1, 70...90),
            (0.4, 0.24, 0.1, 0.13, 50...64),
            (0.62, 0.2, 0.07, 0.13, 36...46),
        ]
        let tint = 0.8 + 0.2 * daylight
        for layer in layers {
            for _ in 0..<3 {
                let width = size.width * .random(in: 0.9...1.5, using: &random)
                let y = size.height * (layer.top + .random(in: 0...0.22, using: &random))
                let slide = wave(time, period: .random(in: layer.period, using: &random), phase: .random(in: 0...1, using: &random))
                let x = CGFloat.random(in: -width * 0.35...size.width * 0.2, using: &random) + width * 0.08 * slide
                let soft = unit * layer.blur
                let band = CGRect(x: x, y: y, width: width, height: unit * layer.height).insetBy(dx: -soft, dy: -soft)
                softEllipse(&context, band, opacity: layer.opacity * tint, solid: 0.35)
            }
        }
    }

    /// Flashes only, no bolt: each strike picks its own shape (a sheet across the sky, a glow inside one cloud,
    /// or a flickering mix), tint (cool white, white or faintly yellow) and strength, kept soft enough not to distract.
    private func drawLightning(in context: inout GraphicsContext, size: CGSize, unit: CGFloat, time: Double?, random: inout SeededRandom) {
        // A still sky has no moment to flash in.
        guard let time else { return }
        let offset = Double.random(in: 0...7, using: &random)
        let cycles = (time + offset) / 7
        let beat = cycles - cycles.rounded(.down)

        // The same choices for every frame of one strike; new ones for the next.
        var strike = SeededRandom(state: UInt64(cycles.rounded(.down)) &* 0x9E37_79B9_7F4A_7C15 ^ 0xA5A5)
        let start = Double.random(in: 0.55...0.88, using: &strike)
        let strength = Double.random(in: 0.12...0.3, using: &strike)
        let tints = [Color(red: 0.84, green: 0.87, blue: 1), Color(red: 0.96, green: 0.97, blue: 1), Color(red: 1, green: 0.95, blue: 0.78)]
        let tint = tints[Int.random(in: 0..<tints.count, using: &strike)]
        let pattern = Int.random(in: 0..<3, using: &strike)
        let spot = CGPoint(
            x: size.width * .random(in: 0.15...0.85, using: &strike),
            y: size.height * .random(in: 0.05...0.35, using: &strike)
        )
        let glowOnly = Bool.random(using: &strike)

        // Cloud style: each pulse of the strike lights a different cloud, so a double or flicker hops between them.
        let layout = lightningStyle == .clouds ? cloudLayout(size: size, unit: unit, time: time) : []
        let hops = layout.isEmpty ? [] : (0..<3).map { _ in layout[Int.random(in: 0..<layout.count, using: &strike)] }

        let t = beat - start
        let stops: [(Double, Double)] = switch pattern {
        case 0: [(0, 0), (0.008, 1), (0.03, 0.15), (0.06, 0)]                                         // One crack.
        case 1: [(0, 0), (0.008, 0.8), (0.02, 0.1), (0.03, 1), (0.05, 0.2), (0.08, 0)]                // Double.
        default: [(0, 0), (0.006, 0.5), (0.015, 0.1), (0.025, 0.9), (0.035, 0.2), (0.045, 0.7), (0.09, 0)] // Flicker.
        }
        let level = Self.envelope(t, stops) * strength
        guard level > 0 else { return }

        if !hops.isEmpty {
            // Pulse boundaries per pattern, matching the stops above.
            let breaks: [Double] = switch pattern {
            case 0: []
            case 1: [0.02]
            default: [0.015, 0.035]
            }
            let cloud = hops[breaks.filter { t > $0 }.count]
            // The glow sits in the cloud's thick middle and spreads a little past its edges.
            let center = CGPoint(x: cloud.x + cloud.width * 0.5, y: cloud.y - cloud.width * 0.04)
            let radius = cloud.width * 0.75
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(tint.opacity(level * 0.25)))
            softEllipse(
                &context,
                CGRect(x: center.x - radius, y: center.y - radius * 0.55, width: radius * 2, height: radius * 1.1),
                color: tint, opacity: min(level * 2, 0.5), solid: 0.15
            )
            return
        }

        // Sheet lightning lights the whole sky; cloud lightning lights one patch and only a little of the rest.
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(tint.opacity(glowOnly ? level * 0.3 : level)))
        let radius = max(size.width, size.height) * (glowOnly ? 0.45 : 0.3)
        softEllipse(
            &context,
            CGRect(x: spot.x - radius, y: spot.y - radius * 0.7, width: radius * 2, height: radius * 1.4),
            color: tint, opacity: min(level * 1.6, 0.45), solid: 0.1
        )
    }

    /// Piecewise-linear value through `(position, value)` stops; 0 outside them.
    private static func envelope(_ position: Double, _ stops: [(Double, Double)]) -> Double {
        guard let first = stops.first, position >= first.0 else { return 0 }
        for (a, b) in zip(stops, stops.dropFirst()) where position <= b.0 {
            return a.1 + (b.1 - a.1) * (position - a.0) / (b.0 - a.0)
        }
        return 0
    }

    /// An ellipse that's solid out to `solid` of its radius and fades to clear at the rim. It stands in for
    /// a blurred shape at a fraction of the cost, since blur filters are redone every frame.
    private func softEllipse(_ context: inout GraphicsContext, _ rect: CGRect, color: Color = .white, opacity: Double, solid: Double) {
        guard opacity > 0, rect.width > 0, rect.height > 0 else { return }
        var unitSpace = context
        unitSpace.translateBy(x: rect.midX, y: rect.midY)
        unitSpace.scaleBy(x: rect.width / 2, y: rect.height / 2)
        unitSpace.fill(
            Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: color.opacity(opacity), location: 0),
                    .init(color: color.opacity(opacity), location: solid),
                    .init(color: color.opacity(0), location: 1),
                ]),
                center: .zero, startRadius: 0, endRadius: 1
            )
        )
    }

    private func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// SplitMix64: a small deterministic generator so a place's stars and clouds don't move between redraws.
private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
