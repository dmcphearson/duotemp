import WidgetKit

struct WeatherEntry: TimelineEntry {
    let date: Date
    let snapshot: WeatherSnapshot?
    let lead: LeadUnit
    let isCurrentLocation: Bool

    static var placeholder: WeatherEntry {
        WeatherEntry(date: .now, snapshot: .sample, lead: .celsius, isCurrentLocation: true)
    }
}

struct Provider: AppIntentTimelineProvider {
    private enum Failure: Error { case locationRemoved }

    func placeholder(in context: Context) -> WeatherEntry {
        .placeholder
    }

    func snapshot(for configuration: SelectLocationIntent, in context: Context) async -> WeatherEntry {
        context.isPreview ? .placeholder : await entry(for: configuration)
    }

    func timeline(for configuration: SelectLocationIntent, in context: Context) async -> Timeline<WeatherEntry> {
        let first = await entry(for: configuration)
        // Step through the hourly forecast on the hour so the widget stays current between fetches.
        let hourly = (first.snapshot?.upcoming(after: first.date) ?? []).map {
            WeatherEntry(date: $0.date, snapshot: first.snapshot, lead: first.lead, isCurrentLocation: first.isCurrentLocation)
        }
        // MET forecasts expire after about 30 minutes; iOS may stretch this to fit the widget's refresh budget.
        let isFresh = first.snapshot.map { -$0.fetchedAt.timeIntervalSinceNow < 300 } ?? false
        let next = Date.now.addingTimeInterval(isFresh ? 30 * 60 : 15 * 60)
        return Timeline(entries: [first] + hourly, policy: .after(next))
    }

    private func entry(for configuration: SelectLocationIntent) async -> WeatherEntry {
        let target = configuration.location ?? .current
        let source = SharedStore.source
        let snapshot: WeatherSnapshot?
        do {
            snapshot = SharedStore.cache(try await fetch(target, source: source), key: target.id)
        } catch {
            snapshot = SharedStore.cachedSnapshot(source: source, key: target.id)
        }
        return WeatherEntry(date: .now, snapshot: snapshot, lead: SharedStore.leadUnit, isCurrentLocation: target.isCurrent)
    }

    private func fetch(_ target: LocationEntity, source: WeatherSource) async throws -> WeatherSnapshot {
        if target.isCurrent {
            let here: Coordinate
            do {
                here = try await OneShotLocation().current()
                SharedStore.lastKnownCoordinate = here
            } catch {
                guard let last = SharedStore.lastKnownCoordinate else { throw error }
                here = last
            }
            let place = await PlaceResolver.describe(here)
            return try await source.snapshot(latitude: here.latitude, longitude: here.longitude, placeName: place.name, timeZoneID: place.timeZoneID)
        }
        guard let saved = SharedStore.locations.first(where: { $0.id.uuidString == target.id }) else {
            throw Failure.locationRemoved
        }
        return try await source.snapshot(latitude: saved.latitude, longitude: saved.longitude, placeName: saved.name, timeZoneID: saved.timeZoneID)
    }
}

extension WeatherSnapshot {
    /// Widget gallery placeholder: a clear night in Dublin.
    static var sample: WeatherSnapshot {
        let start = Calendar.current.dateInterval(of: .hour, for: .now)?.start ?? .now
        func hour(_ offset: Int, _ celsius: Double, _ symbol: String, _ condition: String) -> Hour {
            Hour(
                date: start.addingTimeInterval(Double(offset) * 3600),
                temperature: DualTemp(celsius: celsius),
                feelsLike: DualTemp(celsius: celsius - 2),
                condition: condition,
                symbolName: symbol,
                isDaylight: false
            )
        }
        return WeatherSnapshot(
            placeName: "Dublin",
            timeZoneID: "Europe/Dublin",
            source: .yr,
            fetchedAt: start,
            current: hour(0, 9, "moon.stars", "Clear"),
            high: DualTemp(celsius: 13),
            low: DualTemp(celsius: 7),
            hours: [
                hour(1, 9, "moon.stars", "Clear"),
                hour(2, 8, "moon.stars", "Clear"),
                hour(3, 8, "cloud", "Cloudy"),
                hour(4, 7, "cloud", "Cloudy"),
                hour(5, 7, "cloud.rain", "Rain"),
                hour(6, 7, "cloud.rain", "Rain"),
            ]
        )
    }
}
