import SwiftUI

/// How hard it's raining on the detail screen; nil when it isn't. Cards read it to splash.
enum RainIntensity: Sendable {
    case drizzle, light, heavy

    init?(symbolName: String) {
        let parts = Set(symbolName.split(separator: ".").map(String.init))
        if !parts.isDisjoint(with: ["heavyrain", "bolt"]) {
            self = .heavy
        } else if parts.contains("drizzle") {
            self = .drizzle
        } else if parts.contains("rain") {
            self = .light
        } else {
            return nil
        }
    }
}

/// How rain meets the cards. Mist is the default; the others can be tried from Settings in debug builds.
enum SplashStyle: String, CaseIterable, Sendable {
    /// A thin slanted streak, like the background rain, that dissolves into a soft puff and a glint on the edge.
    case mist
    /// Drops that burst into two droplets and leave beads.
    case droplets
    case off

    static let storageKey = "splashStyle"
}

extension EnvironmentValues {
    @Entry var rainIntensity: RainIntensity? = nil
    /// Sideways drift per point of fall, matching the background rain; see `SkyScene.slant`.
    @Entry var rainSlant: CGFloat = -0.15
}

extension View {
    /// Rain meets this card's top edge in the chosen `SplashStyle`. The detail screen uses it on its top card only.
    func rainSplashes() -> some View {
        modifier(RainSplashes())
    }
}

private struct RainSplashes: ViewModifier {
    @Environment(\.rainIntensity) private var intensity
    @Environment(\.rainSlant) private var slant
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SplashStyle.storageKey) private var style = SplashStyle.mist

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let intensity, style != .off {
                SplashLayer(intensity: intensity, style: style, slant: slant, animated: !reduceMotion)
                    .frame(height: SplashLayer.height)
                    .offset(y: -SplashLayer.height + SplashLayer.edgeInset)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct SplashLayer: View {
    /// Room above the edge for the falling drop and the burst.
    static let height: CGFloat = 26
    /// The edge sits this far above the layer's bottom, so beads straddle it.
    static let edgeInset: CGFloat = 2

    let intensity: RainIntensity
    let style: SplashStyle
    let slant: CGFloat
    let animated: Bool
    @State private var seed = UInt64.random(in: 1...UInt64.max)

    var body: some View {
        if animated {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                canvas(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            canvas(time: nil)
        }
    }

    private func canvas(time: Double?) -> some View {
        let intensity = intensity
        let seed = seed
        return Canvas { context, size in
            if style == .mist {
                drawMist(in: &context, size: size, time: time)
                return
            }
            var random = SplitMix(state: seed)
            let edge = size.height - Self.edgeInset
            let perPoint: CGFloat = switch intensity {
            case .drizzle: 0.012
            case .light: 0.025
            case .heavy: 0.045
            }
            let count = max(1, Int(size.width * perPoint))
            let periods: ClosedRange<Double> = intensity == .heavy ? 0.9...1.7 : 1.4...3.0
            for _ in 0..<count {
                let x = CGFloat.random(in: 8...max(9, size.width - 8), using: &random)
                let period = Double.random(in: periods, using: &random)
                let delay = Double.random(in: 0...period, using: &random)
                guard let time else {
                    context.fill(bead(x: x, edge: edge, stretch: 1), with: .color(.white.opacity(0.3)))
                    continue
                }
                let beat = ((time + delay).truncatingRemainder(dividingBy: period)) / period
                if beat < 0.18 {
                    // The drop falls onto the edge.
                    let progress = beat / 0.18
                    let bottom = edge - (edge - 4) * (1 - progress)
                    var streak = Path()
                    streak.move(to: CGPoint(x: x, y: bottom - 9))
                    streak.addLine(to: CGPoint(x: x, y: bottom))
                    context.stroke(streak, with: .color(.white.opacity(0.7 * min(1, beat / 0.06))), lineWidth: 1)
                } else if beat < 0.34 {
                    // Two droplets fly out and fade.
                    let progress = (beat - 0.18) / 0.16
                    for direction in [-1.0, 1.0] {
                        let point = CGPoint(x: x + direction * 7 * progress, y: edge - 1 - 6.5 * progress)
                        context.fill(
                            Path(ellipseIn: CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2)),
                            with: .color(.white.opacity(0.85 * (1 - progress)))
                        )
                    }
                }
                // The bead swells at impact, then settles.
                let swell = beat < 0.18 ? 0 : beat < 0.21 ? (beat - 0.18) / 0.03 : beat < 0.6 ? 1 - 0.55 * (beat - 0.21) / 0.39 : 0.45 * (1 - (beat - 0.6) / 0.4)
                context.fill(bead(x: x, edge: edge, stretch: 1 + 0.5 * swell), with: .color(.white.opacity(0.2 + 0.75 * swell)))
            }
        }
    }

    /// Streaks slanted like the background rain run into the edge and dissolve into a blurred puff with a
    /// brief glint along the rim. Nothing shows when still.
    private func drawMist(in context: inout GraphicsContext, size: CGSize, time: Double?) {
        guard let time else { return }
        var random = SplitMix(state: seed)
        let edge = size.height - Self.edgeInset
        let (perPoint, periods, streakOpacity): (CGFloat, ClosedRange<Double>, Double) = switch intensity {
        case .drizzle: (0.007, 2.4...4.4, 0.13)
        case .light: (0.014, 1.6...3.4, 0.17)
        case .heavy: (0.026, 1.0...1.8, 0.22)
        }
        let count = max(1, Int(size.width * perPoint))
        var streaks = Path()
        var puffs: [(Path, Double)] = []
        var glints: [(Path, Double)] = []
        for _ in 0..<count {
            let x = CGFloat.random(in: 10...max(11, size.width - 10), using: &random)
            let period = Double.random(in: periods, using: &random)
            let delay = Double.random(in: 0...period, using: &random)
            let beat = ((time + delay).truncatingRemainder(dividingBy: period)) / period
            if beat < 0.2 {
                // Falls at the background rain's slant, ending on the edge.
                let progress = beat / 0.2
                let bottom = edge - (edge - 2) * (1 - progress)
                let drift = -slant * (edge - bottom)
                streaks.move(to: CGPoint(x: x + drift - slant * 10, y: bottom - 10))
                streaks.addLine(to: CGPoint(x: x + drift, y: bottom))
            } else if beat < 0.5 {
                let fade = (beat - 0.2) / 0.3
                let width = 6 + 10 * fade
                puffs.append((Path(ellipseIn: CGRect(x: x - width / 2, y: edge - 2.5, width: width, height: 3.5)), 0.28 * (1 - fade)))
                if fade < 0.5 {
                    var glint = Path()
                    glint.move(to: CGPoint(x: x - width * 0.6, y: edge))
                    glint.addLine(to: CGPoint(x: x + width * 0.6, y: edge))
                    glints.append((glint, 0.22 * (1 - fade * 2)))
                }
            }
        }
        context.stroke(streaks, with: .color(.white.opacity(streakOpacity)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 1.6))
            for (puff, opacity) in puffs {
                layer.fill(puff, with: .color(.white.opacity(opacity)))
            }
        }
        for (glint, opacity) in glints {
            context.stroke(glint, with: .color(.white.opacity(opacity)), lineWidth: 0.75)
        }
    }

    private func bead(x: CGFloat, edge: CGFloat, stretch: CGFloat) -> Path {
        let width = 5 * stretch
        return Path(ellipseIn: CGRect(x: x - width / 2, y: edge - 1.5, width: width, height: 3))
    }
}

/// SplitMix64, so a card's splash spots stay put between frames.
private struct SplitMix: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
