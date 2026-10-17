import Foundation

/// Sun position from NOAA's low-precision equations, accurate to a few minutes around sunrise and sunset.
/// Used to tell day from night for MET hours whose symbol code has no day or night variant, and to place
/// the drawn sun along its arc.
enum Solar {
    /// Sun's elevation at sunrise and sunset, allowing for refraction and the disc's radius.
    private static let horizon = -0.833

    static func isDaylight(at date: Date, latitude: Double, longitude: Double) -> Bool {
        elevation(at: date, latitude: latitude, longitude: longitude) > horizon
    }

    /// Degrees above the horizon, ignoring refraction.
    static func elevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        let (declination, hourAngle) = angles(at: date, longitude: longitude)
        let lat = latitude * .pi / 180
        let cosZenith = sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle)
        return 90 - acos(min(max(cosZenith, -1), 1)) * 180 / .pi
    }

    /// How far through the day the sun is: 0 at sunrise, 0.5 at solar noon, 1 at sunset; nil while it's down.
    static func dayProgress(at date: Date, latitude: Double, longitude: Double) -> Double? {
        let (declination, hourAngle) = angles(at: date, longitude: longitude)
        let lat = latitude * .pi / 180
        let cosSunrise = (sin(horizon * .pi / 180) - sin(lat) * sin(declination)) / (cos(lat) * cos(declination))
        if cosSunrise >= 1 { return nil }                      // Polar night.
        if cosSunrise <= -1 { return (hourAngle + .pi) / (2 * .pi) } // Midnight sun: the whole day is daylight.
        let sunrise = acos(cosSunrise)
        guard abs(hourAngle) <= sunrise else { return nil }
        return (hourAngle + sunrise) / (2 * sunrise)
    }

    /// Declination and hour angle in radians; the hour angle runs from -π to π with 0 at solar noon.
    private static func angles(at date: Date, longitude: Double) -> (declination: Double, hourAngle: Double) {
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
        var degrees = (solarMinutes / 4 - 180).truncatingRemainder(dividingBy: 360)
        if degrees > 180 { degrees -= 360 }
        if degrees < -180 { degrees += 360 }
        return (declination, degrees * .pi / 180)
    }
}
