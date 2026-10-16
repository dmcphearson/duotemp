import SwiftUI
import WeatherKit

/// Credit for the active source: CC BY 4.0 for MET Norway, Apple's mark and legal link for WeatherKit.
struct AttributionView: View {
    let source: WeatherSource
    @State private var apple: WeatherAttribution?

    var body: some View {
        Group {
            switch source {
            case .yr:
                HStack {
                    Text("Forecast data from MET Norway")
                    Spacer()
                    Link("CC BY 4.0", destination: URL(string: "https://api.met.no/doc/License")!)
                }
            case .apple:
                HStack {
                    if let apple {
                        AsyncImage(url: apple.combinedMarkDarkURL) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Text(apple.serviceName)
                        }
                        .frame(height: 14)
                        Spacer()
                        Link("Data sources", destination: apple.legalPageURL)
                    } else {
                        Text("Apple Weather")
                    }
                }
                .task { apple = try? await WeatherService.shared.attribution }
            }
        }
        .font(.footnote)
        .foregroundStyle(Theme.secondary)
    }
}
