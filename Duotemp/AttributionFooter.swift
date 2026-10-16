import SwiftUI
import WeatherKit

/// One compact line crediting each source on screen, expandable to show which source supplied each field.
/// Apple requires its Weather mark and legal link to stay visible wherever its data appears, so both
/// sit in the collapsed line; MET Norway's CC BY 4.0 credit is the name plus the licence link.
struct AttributionFooter: View {
    let sources: [ForecastDetail.Field: WeatherSource]
    var fetchedAt: Date?

    @State private var isExpanded = false
    @State private var apple: WeatherAttribution?

    private var usesApple: Bool { sources.values.contains(.apple) }
    private var usesYr: Bool { sources.values.contains(.yr) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if usesApple {
                    appleMark
                }
                if usesApple && usesYr {
                    Text("·")
                }
                if usesYr {
                    Text("MET Norway")
                }
                Spacer(minLength: 8)
                Button {
                    withAnimation(.snappy) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text("Sources")
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            }
            if usesApple, let apple {
                Link("Apple Weather data sources", destination: apple.legalPageURL)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ForecastDetail.Field.allCases.filter { sources[$0] != nil }, id: \.self) { field in
                        HStack {
                            Text(field.rawValue)
                            Spacer()
                            Text(sources[field]?.creditName ?? "")
                        }
                    }
                    if let fetchedAt {
                        Text("Updated \(fetchedAt, format: .dateTime.hour().minute())")
                            .padding(.top, 4)
                    }
                    if usesYr {
                        Link("MET Norway data, CC BY 4.0", destination: URL(string: "https://api.met.no/doc/License")!)
                    }
                }
                .transition(.opacity)
            }
        }
        .font(.footnote)
        .foregroundStyle(Theme.secondary)
        .padding(.horizontal, 4)
        .task(id: usesApple) {
            if usesApple, apple == nil { apple = try? await WeatherService.shared.attribution }
        }
    }

    @ViewBuilder
    private var appleMark: some View {
        if let apple {
            AsyncImage(url: apple.combinedMarkDarkURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Text(apple.serviceName)
            }
            .frame(height: 12)
            .accessibilityLabel(apple.serviceName)
        } else {
            Text("Apple Weather")
        }
    }
}

extension View {
    /// Styles the footer as a bar pinned above the home indicator; content scrolls behind it.
    func pinnedToBottom() -> some View {
        padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.background.opacity(0.96))
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.secondary.opacity(0.15)).frame(height: 1)
            }
    }
}

extension AttributionFooter {
    /// The list screen shows only snapshot data, which comes entirely from the primary source.
    static func listSources(primary: WeatherSource) -> [ForecastDetail.Field: WeatherSource] {
        [.temperature: primary, .conditions: primary, .forecast: primary]
    }
}
