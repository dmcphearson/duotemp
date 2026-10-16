import MapKit
import SwiftUI

struct AddLocationView: View {
    let onAdd: (SavedLocation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = PlaceSearch()
    @State private var query = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List(search.results, id: \.self) { completion in
                Button {
                    Task { await pick(completion) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(completion.title)
                            .foregroundStyle(.primary)
                        if !completion.subtitle.isEmpty {
                            Text(completion.subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "City or town")
            .onChange(of: query) { search.update(query) }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(
                "Couldn't add that place",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func pick(_ completion: MKLocalSearchCompletion) async {
        do {
            onAdd(try await search.resolve(completion))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Place autocomplete backed by MapKit, limited to addresses (cities, towns, streets).
/// The completer calls its delegate on the main thread, so the conformance is checked at runtime.
@MainActor
@Observable
final class PlaceSearch: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
    private(set) var results: [MKLocalSearchCompletion] = []
    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(_ query: String) {
        if query.isEmpty { results = [] }
        completer.queryFragment = query
    }

    func resolve(_ completion: MKLocalSearchCompletion) async throws -> SavedLocation {
        let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start()
        guard let item = response.mapItems.first else { throw MKError(.placemarkNotFound) }
        let coordinate = item.placemark.coordinate
        return SavedLocation(
            name: item.name ?? completion.title,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timeZoneID: item.timeZone?.identifier
        )
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}
