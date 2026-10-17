import SwiftUI

/// Units, forecast source, widget help and about, behind the gear on the main screen.
struct SettingsView: View {
    @Bindable var model: LocationsModel
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Lead with", selection: $model.lead) {
                        Text("°C").tag(LeadUnit.celsius)
                        Text("°F").tag(LeadUnit.fahrenheit)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Lead with")
                } footer: {
                    Text("The lead unit is larger and first everywhere; the other is always beside it. Wind, pressure, visibility and rain follow the same system.")
                }

                Section {
                    Picker("Forecast", selection: $model.source) {
                        ForEach(WeatherSource.allCases, id: \.self) { source in
                            Text(source.displayName).tag(source)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Forecast")
                } footer: {
                    Text("MET Norway is the default. On a location's detail screen, Apple Weather fills in what MET doesn't forecast, such as chance of rain, gusts and visibility.")
                }
                .listRowBackground(Theme.card)

                Section("Widgets") {
                    Label("Long-press your Home Screen, tap Edit, then Add Widget and choose duotemp.", systemImage: "square.grid.2x2")
                    Label("Tap a widget while editing to choose My Location or a saved place.", systemImage: "hand.tap")
                }
                .listRowBackground(Theme.card)

                Section {
                    LabeledContent("Version", value: version)
                    Link(destination: URL(string: "https://github.com/dmcphearson/duotemp")!) {
                        Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("No accounts, analytics or tracking. Only rounded coordinates leave your device, sent to the forecast provider.")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.accent)
    }
}
