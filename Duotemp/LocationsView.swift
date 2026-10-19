import CoreLocation
import SwiftUI

struct LocationsView: View {
    @State private var model = LocationsModel()
    @State private var isAdding = false
    @State private var isShowingSettings = false
    @State private var path: [String] = []
    @State private var editMode = EditMode.inactive
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
            .environment(\.editMode, $editMode)
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
            // The title stays for the back button's menu and VoiceOver; the wordmark shows instead.
            .toolbar(removing: .title)
            .toolbar {
                // The wordmark without the icon, on the left; everything else is in the one menu on the right.
                // On iOS 26 a leading item sits on a glass pill unless its shared background is hidden.
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .topBarLeading) { wordmark }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { wordmark }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if editMode.isEditing {
                        Button {
                            withAnimation { editMode = .inactive }
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .accessibilityLabel("Done")
                    } else {
                        Menu {
                            Button("Add Location", systemImage: "plus") {
                                isAdding = true
                            }
                            Button("Edit List", systemImage: "pencil") {
                                withAnimation { editMode = .active }
                            }
                            .disabled(model.locations.isEmpty)
                            Button("Settings", systemImage: "gearshape") {
                                isShowingSettings = true
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                        .accessibilityLabel("More")
                    }
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
        // Only in Edit List: outside it a long press would lift the square row behind the rounded card.
        .onMove(perform: reorder)
        if model.locations.isEmpty {
            addPlaceRow
        }
    }

    /// Width over height of Wordmark.svg; a toolbar item otherwise shrinks the image to icon size.
    private static let wordmarkAspect: CGFloat = {
        guard let image = UIImage(named: "Wordmark"), image.size.height > 0 else { return 4 }
        return image.size.width / image.size.height
    }()

    private var wordmark: some View {
        Image("Wordmark")
            .resizable()
            .scaledToFit()
            .frame(width: 38 * Self.wordmarkAspect, height: 38)
            .fixedSize()
            .accessibilityLabel("duoTemp Weather")
            .accessibilityAddTraits(.isHeader)
    }

    /// Shown until the first place is saved, so adding one doesn't depend on finding the menu.
    private var addPlaceRow: some View {
        Button {
            isAdding = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Label("Add a place", systemImage: "plus")
                    .font(.headline)
                Text("Search for a city to follow its weather.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Theme.card)
    }

    private var reorder: ((IndexSet, Int) -> Void)? {
        editMode.isEditing ? { model.move(from: $0, to: $1) } : nil
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
