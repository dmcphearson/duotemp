import CoreGraphics
import Foundation

/// Moon phase from the mean synodic month, counted from the new moon of 6 January 2000 at 18:14 UTC.
/// Within about a day of the true phase, which is plenty for drawing.
enum Lunar {
    private static let synodicMonth = 29.530588853 * 86400
    private static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)

    /// 0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter.
    static func phase(at date: Date) -> Double {
        let cycles = date.timeIntervalSince(referenceNewMoon) / synodicMonth
        return cycles - cycles.rounded(.down)
    }

    /// The lit part of a moon of radius 1 centred on the origin, as a closed outline: the limb is a
    /// half-circle and the terminator a half-ellipse whose width follows cos(phase). Lit on the right
    /// while waxing, on the left while waning. Points are spaced by angle, not height, so the outline
    /// stays round at the poles.
    static func litOutline(phase: Double) -> [CGPoint] {
        let side: CGFloat = phase < 0.5 ? 1 : -1
        let squash = CGFloat(cos(2 * Double.pi * phase))
        let steps = 64
        let angles = (0...steps).map { -CGFloat.pi / 2 + .pi * CGFloat($0) / CGFloat(steps) }
        let limb = angles.map { CGPoint(x: side * cos($0), y: sin($0)) }
        let terminator = angles.reversed().map { CGPoint(x: side * cos($0) * squash, y: sin($0)) }
        return limb + terminator
    }
}
