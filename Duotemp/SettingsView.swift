import SwiftUI

/// Units, forecast source, widget help and about, behind the gear on the main screen.
struct SettingsView: View {
    @Bindable var model: LocationsModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SplashStyle.storageKey) private var splashStyle = SplashStyle.mist
    @AppStorage(SkyAnimation.storageKey) private var skyAnimation = SkyAnimation.everywhere
    @AppStorage(ListBackground.storageKey) private var listBackground = ListBackground.weather

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

                Section {
                    Picker("Animated skies", selection: $skyAnimation) {
                        ForEach(SkyAnimation.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    Picker("List background", selection: $listBackground) {
                        ForEach(ListBackground.allCases, id: \.self) { option in
                            Label {
                                Text(option.displayName)
                            } icon: {
                                swatch(option)
                            }
                            .tag(option)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Still skies use less battery. Weather tints the list with the sky where you are. Widgets are always still.")
                }
                .listRowBackground(Theme.card)

                Section("Widgets") {
                    Label("Long-press your Home Screen, tap Edit, then Add Widget and choose duoTemp Weather.", systemImage: "square.grid.2x2")
                    Label("Tap a widget while editing to choose My Location or a saved place.", systemImage: "hand.tap")
                }
                .listRowBackground(Theme.card)

                Section {
                    LabeledContent("duoTemp Weather", value: version)
                    Link(destination: URL(string: "https://github.com/dmcphearson/duotemp")!) {
                        Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("No accounts, analytics or tracking. Only rounded coordinates leave your device, sent to the forecast provider.")
                }
                .listRowBackground(Theme.card)

                #if DEBUG
                Section {
                    Toggle("Sample skies", isOn: $model.showsSampleSkies)
                    Picker("Rain on cards", selection: $splashStyle) {
                        Text("Mist").tag(SplashStyle.mist)
                        Text("Droplets").tag(SplashStyle.droplets)
                        Text("Off").tag(SplashStyle.off)
                    }
                } header: {
                    Text("Testing")
                } footer: {
                    Text("Sample skies adds a made-up location for every sky to the list. Rain on cards sets how rain meets the detail screen's cards. Debug builds only.")
                }
                .listRowBackground(Theme.card)
                #endif
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

    @ViewBuilder
    private func swatch(_ option: ListBackground) -> some View {
        Group {
            if let color = option.color {
                Circle().fill(color)
            } else {
                Circle().fill(SkyStyle.clearDay.gradient)
            }
        }
        .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
        .frame(width: 20, height: 20)
    }
}
