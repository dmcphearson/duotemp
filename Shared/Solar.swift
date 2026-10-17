import Foundation

/// Sun position from NOAA's low-precision equations, accurate to a few minutes around sunrise and sunset.
/// Used to tell day from night for MET hours whose symbol code has no day or night variant.
enum Solar {
    static func isDaylight(at date: Date, latitude: Double, longitude: Double) -> Bool {
        elevation(at: date, latitude: latitude, longitude: longitude) > -0.833
    }

    /// Degrees above the horizon, ignoring refraction.
    static func elevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let minutes = Double(parts.hour ?? 0) * 60 + Double(parts.minute ?? 0) + Double(parts.second ?? 0) / 60

        let gamma = 2 * Double.pi / 365 * (dayOfYear - 1 + (minutes / 60 - 12) / 24)
        let declination = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
        let equationOfTime = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))

        let solarMinutes = minutes + equationOfTime + 4 * longitude
        let hourAngle = (solarMinutes / 4 - 180) * .pi / 180
        let lat = latitude * .pi / 180
        let cosZenith = sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle)
        return 90 - acos(min(max(cosZenith, -1), 1)) * 180 / .pi
    }
}
