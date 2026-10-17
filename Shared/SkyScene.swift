import SwiftUI

/// A drawn sky for one hour: the SkyStyle gradient plus sun, moon and stars, clouds, rain, snow or fog.
/// Static so it suits widgets and costs nothing between redraws. Stars and clouds are placed from a seed
/// derived from the place name, so a location keeps the same sky between refreshes.
struct SkyScene: View {
    let symbolName: String
    let isDaylight: Bool?
    let sunProgress: Double?
    let sunElevation: Double?
    let moonPhase: Double
    let seed: UInt64
    /// Where the moon sits, and the sun when it doesn't follow the time of day, as a fraction of the size.
    let celestial: UnitPoint
    /// Overrides the moon's place, unclamped, for layouts whose free space isn't near the top.
    let moonAnchor: UnitPoint?

    /// With `sunFollowsTime`, the sun rises at the left edge and sets at the right; widgets turn it off
    /// and keep the sun at `celestial`, clear of their text.
    init(
        hour: WeatherSnapshot.Hour,
        place: String,
        celestial: UnitPoint = UnitPoint(x: 0.95, y: 0.04),
        moonAnchor: UnitPoint? = nil,
        sunFollowsTime: Bool = true
    ) {
        self.celestial = celestial
        self.moonAnchor = moonAnchor
        moonPhase = Lunar.phase(at: hour.date)
        symbolName = hour.symbolName
        isDaylight = hour.isDaylight
        sunProgress = sunFollowsTime ? hour.sunProgress : nil
        sunElevation = hour.sunElevation
        seed = place.utf8.reduce(0xCBF2_9CE4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01B3 }
    }

    var body: some View {
        let style = SkyStyle(symbolName: symbolName, isDaylight: isDaylight)
        let glow = style.glow(sunElevation: sunElevation)
        let decor = Decor(symbolName: symbolName, style: style, isDaylight: isDaylight, glow: glow, moonPhase: moonPhase)
        let seed = seed
        let celestial = celestial
        let sunProgress = sunProgress
        let moonAnchor = moonAnchor
        Canvas { context, size in
            var random = SeededRandom(state: seed)
            decor.draw(in: &context, size: size, celestial: celestial, moonAnchor: moonAnchor, sunProgress: sunProgress, random: &random)
        }
        .background(style.gradient(glow: glow))
        .accessibilityHidden(true)
    }
}

private struct Decor {
    enum Precipitation { case rain(heavy: Bool), snow }

    var sun = false
    var moon = false
    var stars = false
    var clouds = 0
    var night = false
    var fog = false
    /// Sunrise or sunset strength, 0...1; warms the sun.
    var glow = 0.0
    /// 0 new, 0.5 full; see `Lunar`.
    var moonPhase = 0.0
    var precipitation: Precipitation?

    init(symbolName: String, style: SkyStyle, isDaylight: Bool?, glow: Double, moonPhase: Double) {
        self.glow = glow
        self.moonPhase = moonPhase
        let parts = Set(symbolName.split(separator: ".").map(String.init))
        sun = parts.contains("sun")
        moon = parts.contains("moon")
        night = moon || style == .clearNight || style == .cloudyNight || isDaylight == false
        stars = moon
        fog = !parts.isDisjoint(with: ["fog", "haze", "smoke", "dust"])
        if !parts.isDisjoint(with: ["snow", "sleet", "hail", "snowflake"]) {
            precipitation = .snow
        } else if !parts.isDisjoint(with: ["rain", "drizzle", "heavyrain", "bolt"]) {
            precipitation = .rain(heavy: parts.contains("heavyrain") || parts.contains("bolt"))
        }
        if fog {
            clouds = 1
        } else if parts.contains("cloud") {
            clouds = sun || moon ? 2 : 4
        }
    }

    func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        celestial: UnitPoint,
        moonAnchor: UnitPoint?,
        sunProgress: Double?,
        random: inout SeededRandom
    ) {
        let unit = min(size.width, size.height)
        let anchor = CGPoint(x: celestial.x * size.width, y: celestial.y * size.height)
        if stars { drawStars(in: &context, size: size, random: &random) }
        if sun {
            drawSun(in: &context, at: sunProgress.map { sunPosition(progress: $0, size: size, unit: unit) } ?? anchor, unit: unit)
        }
        if moon {
            let center = if let moonAnchor {
                CGPoint(x: moonAnchor.x * size.width, y: moonAnchor.y * size.height)
            } else {
                // Keep the whole moon on screen.
                CGPoint(x: min(max(anchor.x, unit * 0.18), size.width - unit * 0.18), y: max(anchor.y, unit * 0.16))
            }
            drawMoon(in: &context, at: center, unit: unit)
        }
        if fog { drawFog(in: &context, size: size, unit: unit, random: &random) }
        drawClouds(in: &context, size: size, unit: unit, random: &random)
        switch precipitation {
        case .rain(let heavy): drawRain(in: &context, size: size, unit: unit, heavy: heavy, random: &random)
        case .snow: drawSnow(in: &context, size: size, random: &random)
        case nil: break
        }
    }

    /// Along an arc: rising at the left edge, highest at solar noon, setting at the right edge.
    private func sunPosition(progress: Double, size: CGSize, unit: CGFloat) -> CGPoint {
        let height = sin(progress * .pi)
        return CGPoint(x: size.width * progress, y: unit * (0.02 + 0.2 * (1 - height)))
    }

    /// Warm glow with faint halo rings.
    private func drawSun(in context: inout GraphicsContext, at center: CGPoint, unit: CGFloat) {
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
        for fraction in [0.3, 0.5, 0.74, 0.94] {
            context.stroke(circle(center, radius * fraction), with: .color(.white.opacity(0.08)), lineWidth: 1)
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: unit * 0.03))
            layer.fill(circle(center, unit * 0.1), with: .color(Color.white.mix(with: Color(hex: 0xFFD49A), by: glow).opacity(0.8)))
        }
    }

    /// The moon at its phase with a cool glow: lit on the right while waxing, on the left while waning,
    /// with the dark part faintly visible.
    private func drawMoon(in context: inout GraphicsContext, at center: CGPoint, unit: CGFloat) {
        let radius = min(unit * 0.075, 16)
        context.fill(
            circle(center, radius * 6),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.16), .clear]),
                center: center, startRadius: 0, endRadius: radius * 6
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

    private func drawStars(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom) {
        let count = Int(min(size.width * size.height / 1800, 240))
        for index in 0..<count {
            let point = CGPoint(x: .random(in: 0...size.width, using: &random), y: .random(in: 0...size.height * 0.9, using: &random))
            let radius = CGFloat.random(in: 0.4...1.3, using: &random)
            let opacity = Double.random(in: 0.25...0.85, using: &random)
            context.fill(circle(point, radius), with: .color(.white.opacity(opacity)))
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
    private func drawClouds(in context: inout GraphicsContext, size: CGSize, unit: CGFloat, random: inout SeededRandom) {
        guard clouds > 0 else { return }
        let opacity = night ? 0.07 : (clouds > 2 ? 0.12 : 0.16)
        for _ in 0..<clouds {
            let width = min(size.width * .random(in: 0.45...0.75, using: &random), unit * 1.6)
            let x = CGFloat.random(in: -width * 0.3...size.width - width * 0.5, using: &random)
            let y = size.height * .random(in: 0.08...0.6, using: &random)
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

    private func drawRain(in context: inout GraphicsContext, size: CGSize, unit: CGFloat, heavy: Bool, random: inout SeededRandom) {
        let count = Int(min(size.width * size.height / (heavy ? 450 : 800), 600))
        var streaks = Path()
        for _ in 0..<count {
            let length = min(unit * .random(in: 0.04...0.08, using: &random), 16)
            let start = CGPoint(x: .random(in: 0...size.width + 10, using: &random), y: .random(in: -10...size.height, using: &random))
            streaks.move(to: start)
            streaks.addLine(to: CGPoint(x: start.x - length * 0.22, y: start.y + length))
        }
        context.stroke(streaks, with: .color(.white.opacity(heavy ? 0.28 : 0.2)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
    }

    private func drawSnow(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom) {
        let count = Int(min(size.width * size.height / 900, 400))
        var flakes = Path()
        for _ in 0..<count {
            let point = CGPoint(x: .random(in: 0...size.width, using: &random), y: .random(in: 0...size.height, using: &random))
            flakes.addPath(circle(point, .random(in: 1...2.4, using: &random)))
        }
        context.fill(flakes, with: .color(.white.opacity(0.55)))
    }

    private func drawFog(in context: inout GraphicsContext, size: CGSize, unit: CGFloat, random: inout SeededRandom) {
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: unit * 0.05))
            for index in 0..<5 {
                let width = size.width * .random(in: 0.7...1.3, using: &random)
                let y = size.height * (0.3 + 0.13 * CGFloat(index)) + .random(in: -8...8, using: &random)
                let x = CGFloat.random(in: -width * 0.3...size.width * 0.3, using: &random)
                let band = Path(roundedRect: CGRect(x: x, y: y, width: width, height: unit * 0.1), cornerRadius: unit * 0.05)
                layer.fill(band, with: .color(.white.opacity(0.16)))
            }
        }
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
