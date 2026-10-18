import CoreLocation
import SwiftUI

struct LocationsView: View {
    @State private var model = LocationsModel()
    @State private var isAdding = false
    @State private var isShowingSettings = false
    @State private var path: [String] = []
    #if DEBUG
    @MainActor private static var openedLaunchLocation = false
    #endif
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage(ListBackground.storageKey) private var listBackground = ListBackground.weather

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    #if DEBUG
                    if Self.screenshotCities {
                        ForEach(Array(SampleSkies.cityKeys.enumerated()), id: \.element) { index, key in
                            let snapshot = SampleSkies.snapshot(for: key)
                            card(key: key, snapshot: snapshot) { moonSpace in
                                LocationRow(name: snapshot?.placeName ?? key, tag: index == 0 ? "My Location" : nil, snapshot: snapshot, failed: false, lead: model.lead, moonSpace: moonSpace)
                            }
                        }
                    } else {
                        realLocations
                    }
                    #else
                    realLocations
                    #endif
                } footer: {
                    if let updated = model.snapshots.values.map(\.fetchedAt).max() {
                        Text("Updated \(updated, format: .dateTime.hour().minute())")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }
                }
                .listRowSeparator(.hidden)

                #if DEBUG
                if model.showsSampleSkies && !Self.screenshotCities {
                    Section("Sample skies") {
                        ForEach(SampleSkies.keys, id: \.self) { key in
                            let snapshot = SampleSkies.snapshot(for: key)
                            card(key: key, snapshot: snapshot) { moonSpace in
                                LocationRow(name: snapshot?.placeName ?? key, tag: nil, snapshot: snapshot, failed: false, lead: model.lead, moonSpace: moonSpace)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                }
                #endif
            }
            .listRowSpacing(12)
            // The first card sits about 20 points below the toolbar buttons, now the title is in the bar.
            .contentMargins(.top, 9, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background { screenBackground.ignoresSafeArea() }
            .safeAreaInset(edge: .bottom) {
                AttributionFooter(sources: AttributionFooter.listSources(primary: model.source))
                    .pinnedToBottom()
            }
            .navigationTitle("duoTemp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // The wordmark without the icon, centred between Settings and Add.
                    Image("Wordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 38)
                        .accessibilityLabel("duoTemp Weather")
                        .accessibilityAddTraits(.isHeader)
                }
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
                LocationPager(keys: pageKeys, start: key, model: model)
            }
            .sheet(isPresented: $isAdding) {
                AddLocationView { model.add($0) }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(model: model)
            }
            #if DEBUG
            // Screenshots: `-openLocation sample.thunderstorm` opens that place's screen at launch. Once only,
            // or backing out to the list would push it again.
            .onAppear {
                guard !Self.openedLaunchLocation else { return }
                Self.openedLaunchLocation = true
                if let key = UserDefaults.standard.string(forKey: "openLocation") { path = [key] }
            }
            #endif
            .refreshable { await model.refresh() }
            .onChange(of: scenePhase, initial: true) {
                if scenePhase == .active {
                    Task { await model.refresh() }
                }
            }
        }
        .tint(Theme.accent)
    }

    /// My Location and the saved places.
    @ViewBuilder
    private var realLocations: some View {
        currentLocationRow
        ForEach(model.locations) { location in
            let key = location.id.uuidString
            card(key: key) { moonSpace in
                LocationRow(
                    name: location.name,
                    tag: nil,
                    snapshot: model.snapshots[key],
                    failed: model.failed.contains(key),
                    lead: model.lead,
                    moonSpace: moonSpace
                )
            }
        }
        .onDelete(perform: model.delete)
        .onMove(perform: model.move)
    }

    #if DEBUG
    /// `-screenshotCities YES`: the list shows `SampleSkies` cities instead, for App Store screenshots.
    private static var screenshotCities: Bool { UserDefaults.standard.bool(forKey: "screenshotCities") }
    #endif

    /// Every card's key in list order, for paging between locations.
    private var pageKeys: [String] {
        #if DEBUG
        if Self.screenshotCities { return SampleSkies.cityKeys }
        #endif
        var keys: [String] = []
        if model.authorization.isAuthorized { keys.append(SharedStore.currentLocationKey) }
        keys += model.locations.map(\.id.uuidString)
        #if DEBUG
        if model.showsSampleSkies { keys += SampleSkies.keys }
        #endif
        return keys
    }

    /// A tappable card without the list's disclosure chevron, on its sky. It pushes through the path itself,
    /// once: a hidden NavigationLink behind a list row could fire twice and open the screen a second time.
    private func card<Content: View>(
        key: String, snapshot: WeatherSnapshot? = nil, @ViewBuilder content: @escaping (Binding<CGRect?>) -> Content
    ) -> some View {
        SkyCard(snapshot: snapshot ?? model.snapshots[key], content: content) {
            if path.last != key { path.append(key) }
        }
    }

    /// The first card's sky, dimmed, so the screen takes on the weather where you are.
    @ViewBuilder
    private var screenBackground: some View {
        if let color = listBackground.color {
            color
        } else {
            weatherBackground
        }
    }

    private var firstSnapshot: WeatherSnapshot? {
        #if DEBUG
        if Self.screenshotCities { return SampleSkies.cityKeys.first.flatMap { SampleSkies.snapshot(for: $0) } }
        #endif
        return model.snapshots[SharedStore.currentLocationKey] ?? model.locations.first.flatMap { model.snapshots[$0.id.uuidString] }
    }

    @ViewBuilder
    private var weatherBackground: some View {
        let first = firstSnapshot
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
            card(key: key) { moonSpace in
                LocationRow(
                    name: model.snapshots[key]?.placeName ?? "My Location",
                    tag: "My Location",
                    snapshot: model.snapshots[key],
                    failed: model.failed.contains(key),
                    lead: model.lead,
                    failureText: "Couldn't find your location. Pull to retry.",
                    moonSpace: moonSpace
                )
            }
        }
    }
}

/// A card row whose sky places its moon in the open space the card's text reports.
private struct SkyCard<Content: View>: View {
    let snapshot: WeatherSnapshot?
    let content: (Binding<CGRect?>) -> Content
    let open: () -> Void
    @State private var moonSpace: CGRect?

    var body: some View {
        Button(action: open) {
            content($moonSpace)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(LocationRow.background(for: snapshot, moonSpace: moonSpace))
        .listRowInsets(LocationRow.insets)
    }
}
