import CryptoKit
import DeviceCheck
import Foundation
import OSLog

/// Gets a token for duoTemp's proxy with App Attest when there's none or it expires within two days, and
/// stores it in the App Group for the app and widgets. Each attestation uses a new key. Simulators and
/// builds without a proxy skip it and call the sources directly.
actor Attestor {
    static let shared = Attestor()

    private static let log = Logger(subsystem: "me.mcphearson.duotemp", category: "Attest")
    private static let renewWithin: TimeInterval = 2 * 24 * 3600
    private static let retryAfter: TimeInterval = 3600

    private var running = false
    private var lastAttempt: Date?

    func refreshIfNeeded(now: Date = .now) async {
        guard !running, let base = ProxyAccess.baseURL, DCAppAttestService.shared.isSupported else { return }
        if let token = SharedStore.proxyToken, token.expires > now.addingTimeInterval(Self.renewWithin) { return }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < Self.retryAfter { return }
        running = true
        lastAttempt = now
        defer { running = false }
        do {
            SharedStore.proxyToken = try await attest(base: base)
            Self.log.info("[duotemp] Proxy token issued")
        } catch {
            Self.log.error("[duotemp] Error: attestation failed: \(error.localizedDescription)")
        }
    }

    private struct Challenge: Decodable {
        let challenge: String
    }

    private struct Issued: Decodable {
        let token: String
        /// Milliseconds since 1970.
        let expires: Double
    }

    private func attest(base: URL) async throws -> SharedStore.ProxyToken {
        let challenge = try JSONDecoder().decode(Challenge.self, from: try await send(URLRequest(url: base.appending(path: "attest/challenge")))).challenge
        let service = DCAppAttestService.shared
        let keyID = try await service.generateKey()
        let attestation = try await service.attestKey(keyID, clientDataHash: Data(SHA256.hash(data: Data(challenge.utf8))))

        var request = URLRequest(url: base.appending(path: "attest"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "keyId": keyID,
            "attestation": attestation.base64EncodedString(),
            "challenge": challenge,
        ])
        let issued = try JSONDecoder().decode(Issued.self, from: try await send(request))
        return SharedStore.ProxyToken(value: issued.token, expires: Date(timeIntervalSince1970: issued.expires / 1000))
    }

    private func send(_ request: URLRequest) async throws -> Data {
        var request = request
        request.setValue(UserAgent.value, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            Self.log.error("[duotemp] Error: \(request.url?.path() ?? "") returned HTTP \(status)")
            throw URLError(.badServerResponse)
        }
        return data
    }
}
