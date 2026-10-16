import CoreLocation
import SwiftUI

struct LocationsView: View {
    @State private var model = LocationsModel()
    @State private var isAdding = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Lead with") {
                        Picker("Lead with", selection: $model.lead) {
                            Text("°C").tag(LeadUnit.celsius)
                            Text("°F").tag(LeadUnit.fahrenheit)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                    Picker("Forecast", selection: $model.source) {
                        ForEach(WeatherSource.allCases, id: \.self) { source in
                            Text(source.displayName).tag(source)
                        }
                    }
                }
                .listRowBackground(Theme.card)

                Section {
                    currentLocationRow
                    ForEach(model.locations) { location in
                        let key = location.id.uuidString
                        LocationRow(
                            name: location.name,
                            tag: nil,
                            snapshot: model.snapshots[key],
                            failed: model.failed.contains(key),
                            lead: model.lead
                        )
                    }
                    .onDelete(perform: model.delete)
                    .onMove(perform: model.move)
                } footer: {
                    Text("Long-press your Home Screen, add the duotemp widget, then tap it while editing to choose a location.")
                }
                .listRowBackground(Theme.card)

                Section {
                    AttributionView(source: model.source)
                }
                .listRowBackground(Color.clear)
            }
            .listRowSpacing(10)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Locations")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add location")
                }
            }
            .sheet(isPresented: $isAdding) {
                AddLocationView { model.add($0) }
            }
            .refreshable { await model.refresh() }
            .onChange(of: scenePhase, initial: true) {
                if scenePhase == .active {
                    Task { await model.refresh() }
                }
            }
        }
        .tint(Theme.accent)
    }

    @ViewBuilder
    private var currentLocationRow: some View {
        let key = SharedStore.currentLocationKey
        switch model.authorization {
        case .notDetermined:
            Button {
                model.requestLocationAccess()
            } label: {
                Label("Show weather for my location", systemImage: "location.fill")
            }
        case .denied, .restricted:
            VStack(alignment: .leading, spacing: 6) {
                Text("Location access is off")
                    .font(.headline)
                Text("Turn it on to see your local weather here and in widgets.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
            .padding(.vertical, 4)
        default:
            LocationRow(
                name: model.snapshots[key]?.placeName ?? "My Location",
                tag: "MY LOCATION",
                snapshot: model.snapshots[key],
                failed: model.failed.contains(key),
                lead: model.lead,
                failureText: "Couldn't find your location. Pull to retry."
            )
        }
    }
}
