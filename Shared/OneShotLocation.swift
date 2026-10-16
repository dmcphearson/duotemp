import CoreLocation

/// One location fix for the app or a widget timeline, with a timeout so a widget never hangs.
@MainActor
final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    enum Failure: LocalizedError {
        case timedOut
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .timedOut: "Timed out waiting for a location."
            case .failed(let message): message
            }
        }
    }

    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Coordinate, Error>?
    private var inFlight: Task<Coordinate, Error>?
    private var requestID = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// A fix no older than `maxAge`, or a fresh one within `timeout`. Concurrent callers share one request.
    func current(maxAge: TimeInterval = 900, timeout: Duration = .seconds(10)) async throws -> Coordinate {
        if let last = manager.location, -last.timestamp.timeIntervalSinceNow < maxAge {
            return Coordinate(last)
        }
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task { try await request(timeout: timeout) }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    private func request(timeout: Duration) async throws -> Coordinate {
        requestID += 1
        let id = requestID
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
            Task {
                try? await Task.sleep(for: timeout)
                if self.requestID == id { self.finish(.failure(Failure.timedOut)) }
            }
        }
    }

    private func finish(_ result: Result<Coordinate, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let coordinate = Coordinate(last)
        Task { @MainActor in self.finish(.success(coordinate)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in self.finish(.failure(Failure.failed(message))) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.onAuthorizationChange?(status) }
    }
}

extension Coordinate {
    init(_ location: CLLocation) {
        self.init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, timestamp: location.timestamp)
    }
}

extension CLAuthorizationStatus {
    var isAuthorized: Bool {
        self == .authorizedWhenInUse || self == .authorizedAlways
    }
}
