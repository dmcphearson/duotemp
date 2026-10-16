import SwiftUI

@main
struct DuotempApp: App {
    var body: some Scene {
        WindowGroup {
            LocationsView()
                .preferredColorScheme(.dark)
        }
    }
}
