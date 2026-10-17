import SwiftUI

/// Where the skies move. Off draws a still sky; Reduce Motion still applies on top of this.
enum SkyAnimation: String, CaseIterable {
    case everywhere, detailOnly, off

    static let storageKey = "skyAnimation"

    var displayName: String {
        switch self {
        case .everywhere: "Everywhere"
        case .detailOnly: "Location screen only"
        case .off: "Off"
        }
    }

    var animatesList: Bool { self == .everywhere }
    var animatesDetail: Bool { self != .off }
}

/// The list screen's backdrop: the dimmed sky where you are, or a plain colour.
enum ListBackground: String, CaseIterable {
    case weather, midnight, slate, plum, forest, black

    static let storageKey = "listBackground"

    var displayName: String {
        switch self {
        case .weather: "Weather"
        case .midnight: "Midnight"
        case .slate: "Slate"
        case .plum: "Plum"
        case .forest: "Forest"
        case .black: "Black"
        }
    }

    /// The plain colour, or nil for the weather backdrop.
    var color: Color? {
        switch self {
        case .weather: nil
        case .midnight: Theme.background
        case .slate: Color(hex: 0x262D36)
        case .plum: Color(hex: 0x2A2238)
        case .forest: Color(hex: 0x1A2A25)
        case .black: .black
        }
    }
}
