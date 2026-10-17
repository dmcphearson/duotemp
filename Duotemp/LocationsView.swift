import CoreLocation
import SwiftUI

struct LocationsView: View {
    @State private var model = LocationsModel()
    @State private var isAdding = false
    @State private var isShowingSettings = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    currentLocationRow
                    ForEach(model.locations) { location in
                        let key = location.id.uuidString
                        card(key: key) {
                            LocationRow(
                                name: location.name,
                                tag: nil,
                                snapshot: model.snapshots[key],
                                failed: model.failed.contains(key),
                                lead: model.lead
                            )
                        }
                    }
                    .onDelete(perform: model.delete)
                    .onMove(perform: model.move)
                } footer: {
                    if let updated = model.snapshots.values.map(\.fetchedAt).max() {
                        Text("Updated \(updated, format: .dateTime.hour().minute())")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }
                }
                .listRowSeparator(.hidden)

                #if DEBUG
                if model.showsSampleSkies {
                    Section("Sample skies") {
                        ForEach(SampleSkies.keys, id: \.self) { key in
                            let snapshot = SampleSkies.snapshot(for: key)
                            card(key: key, snapshot: snapshot) {
                                LocationRow(name: snapshot?.placeName ?? key, tag: nil, snapshot: snapshot, failed: false, lead: model.lead)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                }
                #endif
            }
            .listRowSpacing(12)
            .scrollContentBackground(.hidden)
            .background { screenBackground.ignoresSafeArea() }
            .safeAreaInset(edge: .bottom) {
                AttributionFooter(sources: AttributionFooter.listSources(primary: model.source))
                    .pinnedToBottom()
            }
            .navigationTitle("duotemp")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if model.locations.count > 1 {
                        EditButton()
                    }
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add location")
                }
            }
            .navigationDestination(for: String.self) { key in
                if let target = model.target(for: key) {
                    LocationDetailView(target: target, model: model)
                } else {
                    ContentUnavailableView("Location unavailable", systemImage: "location.slash")
                }
            }
            .sheet(isPresented: $isAdding) {
                AddLocationView { model.add($0) }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(model: model)
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

    /// A tappable card without the list's disclosure chevron, on its sky.
    private func card<Content: View>(key: String, snapshot: WeatherSnapshot? = nil, @ViewBuilder content: () -> Content) -> some View {
        content()
            .background {
                NavigationLink(value: key) { EmptyView() }
                    .opacity(0)
            }
            .listRowBackground(LocationRow.background(for: snapshot ?? model.snapshots[key]))
            .listRowInsets(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
    }

    /// The first card's sky, dimmed, so the screen takes on the weather where you are.
    @ViewBuilder
    private var screenBackground: some View {
        let first = model.snapshots[SharedStore.currentLocationKey] ?? model.locations.first.flatMap { model.snapshots[$0.id.uuidString] }
        if let first {
            SkyStyle(hour: first.now(at: .now)).gradient
                .overlay(Theme.background.opacity(0.72))
        } else {
            Theme.background
        }
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
                    .font(.headline)
                    .padding(.vertical, 8)
            }
            .listRowBackground(Theme.card)
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
            .listRowBackground(Theme.card)
        default:
            card(key: key) {
                LocationRow(
                    name: model.snapshots[key]?.placeName ?? "My Location",
                    tag: "My Location",
                    snapshot: model.snapshots[key],
                    failed: model.failed.contains(key),
                    lead: model.lead,
                    failureText: "Couldn't find your location. Pull to retry."
                )
            }
        }
    }
}
