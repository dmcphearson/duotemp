import SwiftUI

/// Full-screen locations in list order; swipe sideways to move between them.
struct LocationPager: View {
    let keys: [String]
    let model: LocationsModel
    @State private var selection: String
    @AppStorage(SkyAnimation.storageKey) private var animation = SkyAnimation.everywhere
    /// Each page's loaded forecast, for the sources bar.
    @State private var loaded: [String: ForecastDetail] = [:]

    init(keys: [String], start: String, model: LocationsModel) {
        self.keys = keys.contains(start) ? keys : [start]
        self.model = model
        _selection = State(initialValue: start)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(keys, id: \.self) { key in
                Group {
                    if let target = model.target(for: key) {
                        LocationDetailView(target: target, model: model) { loaded[key] = $0 }
                    } else {
                        ContentUnavailableView("Location unavailable", systemImage: "location.slash")
                    }
                }
                .tag(key)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // Outside the pages, so its fill can run under the home indicator; a page's content stops at its edge.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let detail = loaded[selection] {
                AttributionFooter(sources: detail.sources, fetchedAt: detail.snapshot.fetchedAt)
                    .pinnedToBottom()
            }
        }
        // The sky sits behind the pager, not each page, so it runs up under the navigation bar.
        .background { sky.ignoresSafeArea() }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle(model.target(for: selection)?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if keys.count > 1 {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 7) {
                        Text(model.target(for: selection)?.name ?? "")
                            .font(.headline)
                            .lineLimit(1)
                        PageDots(count: keys.count, index: keys.firstIndex(of: selection) ?? 0)
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

extension LocationPager {
    /// The selected place's sky for the hour on screen; it crossfades as you swipe to the next place.
    private var sky: some View {
        ZStack {
            if let snapshot = snapshot(for: selection) {
                let now = snapshot.now(at: .now)
                // The moon sits right of the temperature, below the navigation bar.
                SkyScene(
                    hour: now, next: snapshot.hour(after: now), place: snapshot.placeName,
                    moonAnchor: UnitPoint(x: 0.86, y: 0.2), animated: animation.animatesDetail
                )
                    .id(selection)
                    .transition(.opacity)
            } else {
                Theme.background
            }
        }
        .animation(.easeInOut(duration: 0.35), value: selection)
    }

    private func snapshot(for key: String) -> WeatherSnapshot? {
        #if DEBUG
        if let sample = SampleSkies.snapshot(for: key) { return sample }
        #endif
        return model.snapshots[key]
    }
}

/// Apple-style page dots under the title, so they never sit on the sources footer.
private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { dot in
                Circle()
                    .fill(.white.opacity(dot == index ? 0.95 : 0.35))
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Location \(index + 1) of \(count)")
    }
}
