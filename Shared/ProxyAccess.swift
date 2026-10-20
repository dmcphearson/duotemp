import Foundation

/// duoTemp's caching proxy, used only with a valid App Attest token (the app gets one with `Attestor`).
/// Without one, and in builds with no PROXY_BASE_URL (forks, simulators, which can't attest), requests
/// go to MET and the aurora sources directly.
enum ProxyAccess {
    static let tokenHeader = "X-Duotemp-Token"

    static var baseURL: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "ProxyBaseURL") as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }

    /// The proxy and token to use, or nil to call the source directly.
    static func route(now: Date = .now) -> (base: URL, token: String)? {
        guard let base = baseURL, let token = SharedStore.proxyToken, token.expires > now.addingTimeInterval(60) else { return nil }
        return (base, token.value)
    }

    /// The proxy refused the token (for example after its secret changed): drop it so the app attests again.
    static func tokenRejected() {
        SharedStore.proxyToken = nil
    }
}
