import Foundation

/// The User-Agent for MET and the aurora sources, which MET's terms require to name the app and give a
/// contact. Set by USER_AGENT_NAME and USER_AGENT_CONTACT in xcconfig; a build that sets neither sends its
/// own bundle ID, so a fork never identifies as duoTemp.
enum UserAgent {
    static let value: String = {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "0"
        let name = (info["UserAgentName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? appBundleID
        let contact = (info["UserAgentContact"] as? String) ?? ""
        return contact.isEmpty ? "\(name)/\(version)" : "\(name)/\(version) \(contact)"
    }()

    /// The app's bundle ID, also from the widget extension.
    private static var appBundleID: String {
        let bundleID = Bundle.main.bundleIdentifier ?? "duotemp-source-build"
        return bundleID.hasSuffix(".widgets") ? String(bundleID.dropLast(".widgets".count)) : bundleID
    }
}
