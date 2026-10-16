import Foundation

extension WeatherSource {
    func snapshot(latitude: Double, longitude: Double, placeName: String, timeZoneID: String?) async throws -> WeatherSnapshot {
        switch self {
        case .yr:
            try await METClient.snapshot(latitude: latitude, longitude: longitude, placeName: placeName, timeZoneID: timeZoneID)
        case .apple:
            try await AppleWeatherClient.snapshot(latitude: latitude, longitude: longitude, placeName: placeName, timeZoneID: timeZoneID)
        }
    }
}
