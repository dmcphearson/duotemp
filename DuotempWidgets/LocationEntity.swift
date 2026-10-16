import AppIntents
import WidgetKit

/// A widget location: "My Location" or one of the places saved in the app.
struct LocationEntity: AppEntity {
    static let currentID = SharedStore.currentLocationKey
    static let current = LocationEntity(id: currentID, name: "My Location")
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Location"
    static let defaultQuery = LocationQuery()

    let id: String
    let name: String

    var isCurrent: Bool { id == Self.currentID }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct LocationQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LocationEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [LocationEntity] {
        [.current] + SharedStore.locations.map { LocationEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func defaultResult() async -> LocationEntity? {
        .current
    }
}

struct SelectLocationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Location"
    static let description = IntentDescription("Choose which location the widget shows.")

    @Parameter(title: "Location")
    var location: LocationEntity?
}
