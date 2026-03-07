import Foundation
import Logging

// MARK: - Bridge API Client

/// HTTP client for the acp-ws-bridge REST API.
///
/// Provides typed access to all bridge endpoints including health checks,
/// session management, copilot info/usage, and history queries.
///
/// ```swift
/// let client = BridgeAPIClient(
///     baseURL: URL(string: "https://localhost:8766")!,
///     trustSelfSigned: true
/// )
/// let health = try await client.health()
/// ```
public actor BridgeAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let logger: Logger
    private let decoder: JSONDecoder

    /// Creates a new bridge API client.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL of the acp-ws-bridge REST API (e.g. `https://localhost:8766`).
    ///   - trustSelfSigned: When `true`, accepts self-signed TLS certificates. Defaults to `false`.
    ///   - logger: Optional logger. Falls back to a default logger labeled `"acp.bridge"`.
    public init(baseURL: URL, trustSelfSigned: Bool = false, logger: Logger? = nil) {
        self.baseURL = baseURL
        self.logger = logger ?? Logger(label: "acp.bridge")
        self.decoder = JSONDecoder()

        if trustSelfSigned {
            let delegate = BridgeSessionDelegate()
            self.session = URLSession(
                configuration: .default,
                delegate: delegate,
                delegateQueue: nil
            )
        } else {
            self.session = URLSession.shared
        }
    }

    // MARK: - Health

    /// Fetch bridge health status.
    ///
    /// `GET /health`
    public func health() async throws -> BridgeHealth {
        try await get("/health")
    }

    // MARK: - Copilot

    /// Fetch Copilot CLI information.
    ///
    /// `GET /api/copilot/info`
    public func copilotInfo() async throws -> CopilotInfo {
        try await get("/api/copilot/info")
    }

    /// Fetch Copilot usage statistics.
    ///
    /// `GET /api/copilot/usage`
    public func copilotUsage() async throws -> CopilotUsage {
        try await get("/api/copilot/usage")
    }

    // MARK: - Sessions

    /// List all active sessions.
    ///
    /// `GET /api/sessions`
    public func sessions() async throws -> [BridgeSession] {
        try await get("/api/sessions")
    }

    /// Fetch a single session by ID.
    ///
    /// `GET /api/sessions/:id`
    public func session(id: String) async throws -> BridgeSession {
        try await get("/api/sessions/\(id)")
    }

    /// Delete a session by ID.
    ///
    /// `DELETE /api/sessions/:id`
    public func deleteSession(id: String) async throws {
        try await delete("/api/sessions/\(id)")
    }

    /// List commands available for a session.
    ///
    /// `GET /api/sessions/:id/commands`
    public func sessionCommands(id: String) async throws -> [BridgeCommand] {
        try await get("/api/sessions/\(id)/commands")
    }

    // MARK: - Stats

    /// Fetch aggregate bridge statistics.
    ///
    /// `GET /api/stats`
    public func stats() async throws -> BridgeStats {
        try await get("/api/stats")
    }

    // MARK: - History

    /// List all history sessions.
    ///
    /// `GET /api/history/sessions`
    public func historySessions() async throws -> [HistorySession] {
        try await get("/api/history/sessions")
    }

    /// Fetch turns for a history session.
    ///
    /// `GET /api/history/sessions/:id/turns`
    public func historyTurns(sessionId: String) async throws -> [HistoryTurn] {
        try await get("/api/history/sessions/\(sessionId)/turns")
    }

    /// Fetch aggregate history statistics.
    ///
    /// `GET /api/history/stats`
    public func historyStats() async throws -> HistoryStats {
        try await get("/api/history/stats")
    }

    // MARK: - Internal Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        logger.debug("GET \(url.absoluteString)")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw BridgeAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            logger.error("HTTP \(http.statusCode): \(body ?? "<no body>")")
            throw BridgeAPIError.httpError(statusCode: http.statusCode, body: body)
        }
        return try decoder.decode(T.self, from: data)
    }

    private func delete(_ path: String) async throws {
        let url = baseURL.appendingPathComponent(path)
        logger.debug("DELETE \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BridgeAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            logger.error("HTTP \(http.statusCode): \(body ?? "<no body>")")
            throw BridgeAPIError.httpError(statusCode: http.statusCode, body: body)
        }
    }
}

// MARK: - Error

/// Errors from the bridge REST API client.
public enum BridgeAPIError: Error, Sendable {
    /// The response was not a valid HTTP response.
    case invalidResponse
    /// The server returned a non-2xx status code.
    case httpError(statusCode: Int, body: String?)
}

// MARK: - Self-Signed TLS Delegate

/// URLSession delegate that accepts self-signed TLS certificates for bridge connections.
private final class BridgeSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: serverTrust))
    }
}
