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
}
