import CoreLocation
import Observation
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class LocationsModel {
    private(set) var locations = SharedStore.locations
    private(set) var snapshots: [String: WeatherSnapshot] = [:]
    private(set) var failed: Set<String> = []
    private(set) var authorization: CLAuthorizationStatus = .notDetermined

    var lead = SharedStore.leadUnit {
        didSet {
            SharedStore.leadUnit = lead
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var source = SharedStore.source {
        didSet {
            guard source != oldValue else { return }
            SharedStore.source = source
            snapshots = cachedSnapshots()
            Task { await refresh() }
        }
    }

    @ObservationIgnored private let locator = OneShotLocation()
    @ObservationIgnored private var isRefreshing = false

    init() {
        authorization = locator.authorizationStatus
        snapshots = cachedSnapshots()
        locator.onAuthorizationChange = { [weak self] status in
            guard let self, status != self.authorization else { return }
            self.authorization = status
            Task { await self.refresh() }
        }
    }

    func requestLocationAccess() {
        locator.requestAuthorization()
    }

    /// Fetches every location in parallel. Failures keep the last good forecast on screen.
    func refresh() async {
        // Launch fires several triggers at once (scene active, authorization callback); one refresh covers them.
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let source = source
        var jobs = locations.map {
            Job(key: $0.id.uuidString, latitude: $0.latitude, longitude: $0.longitude, name: $0.name, timeZoneID: $0.timeZoneID)
        }
        if authorization.isAuthorized {
            if let here = await currentCoordinate() {
                let place = await PlaceResolver.describe(here)
                jobs.insert(Job(key: SharedStore.currentLocationKey, latitude: here.latitude, longitude: here.longitude, name: place.name, timeZoneID: place.timeZoneID), at: 0)
            } else {
                failed.insert(SharedStore.currentLocationKey)
            }
        }

        await withTaskGroup(of: (String, WeatherSnapshot?).self) { group in
            for job in jobs {
                group.addTask {
                    (job.key, try? await source.snapshot(latitude: job.latitude, longitude: job.longitude, placeName: job.name, timeZoneID: job.timeZoneID))
                }
            }
            for await (key, snapshot) in group {
                if let snapshot {
                    snapshots[key] = SharedStore.cache(snapshot, key: key)
                    failed.remove(key)
                } else {
                    failed.insert(key)
                }
            }
        }
        // Reloads requested while the app is in the foreground don't count against the widgets' budget.
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// A fresh fix, else the last known one (for example when GPS times out indoors).
    private func currentCoordinate() async -> Coordinate? {
        do {
            let here = try await locator.current()
            SharedStore.lastKnownCoordinate = here
            return here
        } catch {
            return SharedStore.lastKnownCoordinate
        }
    }

    func add(_ location: SavedLocation) {
        locations.append(location)
        save()
        Task { await refresh() }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            SharedStore.removeCache(key: locations[index].id.uuidString)
        }
        locations.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        locations.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func save() {
        SharedStore.locations = locations
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func cachedSnapshots() -> [String: WeatherSnapshot] {
        let keys = [SharedStore.currentLocationKey] + locations.map(\.id.uuidString)
        var result: [String: WeatherSnapshot] = [:]
        for key in keys {
            result[key] = SharedStore.cachedSnapshot(source: source, key: key)
        }
        return result
    }
}

private struct Job: Sendable {
    let key: String
    let latitude: Double
    let longitude: Double
    let name: String
    let timeZoneID: String?
}
