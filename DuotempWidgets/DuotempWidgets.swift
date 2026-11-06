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
        // Home Screen sizes and the rectangular Lock Screen size; circular and inline return with their
        // restyle (#236). Widgets added before places could be chosen have no location set and show My Location.
        AppIntentConfiguration(kind: "WeatherWidget", intent: SelectLocationIntent.self, provider: Provider()) { entry in
            WeatherWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground(entry: entry) }
        }
        .configurationDisplayName("duoTemp Weather")
        .description("Celsius and Fahrenheit together, with feels-like.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
