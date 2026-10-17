import SwiftUI

/// How hard it's raining on the detail screen; nil when it isn't. Cards read it to splash.
enum RainIntensity: Sendable {
    case light, heavy

    init?(symbolName: String) {
        let parts = Set(symbolName.split(separator: ".").map(String.init))
        if !parts.isDisjoint(with: ["heavyrain", "bolt"]) {
            self = .heavy
        } else if !parts.isDisjoint(with: ["rain", "drizzle"]) {
            self = .light
        } else {
            return nil
        }
    }
}

extension EnvironmentValues {
    @Entry var rainIntensity: RainIntensity? = nil
}

extension View {
    /// Raindrops land on this card's top edge, burst into two droplets and leave beads.
    func rainSplashes() -> some View {
        modifier(RainSplashes())
    }
}

private struct RainSplashes: ViewModifier {
    @Environment(\.rainIntensity) private var intensity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let intensity {
                SplashLayer(intensity: intensity, animated: !reduceMotion)
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
            var random = SplitMix(state: seed)
            let edge = size.height - Self.edgeInset
            let perPoint: CGFloat = intensity == .heavy ? 0.045 : 0.025
            let count = max(2, Int(size.width * perPoint))
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
