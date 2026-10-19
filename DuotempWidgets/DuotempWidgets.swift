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
        // Free widgets show My Location on the Home Screen only. Lock Screen sizes and choosing a saved
        // place (SelectLocationIntent) are for the paid tier.
        StaticConfiguration(kind: "WeatherWidget", provider: Provider()) { entry in
            WeatherWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground(entry: entry) }
        }
        .configurationDisplayName("duoTemp Weather")
        .description("Celsius and Fahrenheit together, with feels-like.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
