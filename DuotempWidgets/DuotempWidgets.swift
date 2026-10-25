import SwiftUI
import WidgetKit

@main
struct DuotempWidgets: WidgetBundle {
    var body: some Widget {
        WeatherWidget()
    }
}

struct WeatherWidget: Widget {
    var body: some WidgetConfiguration {
        // Home Screen sizes; the Lock Screen sizes return with their restyle. Widgets added before places
        // could be chosen have no location set and show My Location.
        AppIntentConfiguration(kind: "WeatherWidget", intent: SelectLocationIntent.self, provider: Provider()) { entry in
            WeatherWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground(entry: entry) }
        }
        .configurationDisplayName("duoTemp Weather")
        .description("Celsius and Fahrenheit together, with feels-like.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
