import SwiftUI

/// Full-screen locations in list order; swipe sideways to move between them.
struct LocationPager: View {
    let keys: [String]
    let model: LocationsModel
    @State private var selection: String

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
                        LocationDetailView(target: target, model: model)
                    } else {
                        ContentUnavailableView("Location unavailable", systemImage: "location.slash")
                    }
                }
                .tag(key)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .bottom)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(model.target(for: selection)?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if keys.count > 1 {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 4) {
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
