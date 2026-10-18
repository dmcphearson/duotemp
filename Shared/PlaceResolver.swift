import CoreLocation

enum PlaceResolver {
    /// Locality and time zone for a coordinate. Falls back to "My Location" when geocoding fails (offline, rate-limited).
    static func describe(_ coordinate: Coordinate) async -> (name: String, timeZoneID: String?) {
        if let cached = SharedStore.cachedPlace(near: coordinate) { return cached }

        let location = CLLocation(approximateLatitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
            return ("My Location", nil)
        }
        let name = placemark.locality ?? placemark.subLocality ?? placemark.name ?? "My Location"
        let timeZoneID = placemark.timeZone?.identifier
        SharedStore.cachePlace(name: name, timeZoneID: timeZoneID, near: coordinate)
        return (name, timeZoneID)
    }
}
