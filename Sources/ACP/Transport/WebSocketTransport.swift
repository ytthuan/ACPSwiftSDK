import Foundation
#if canImport(Security)
import Security
#endif
import Logging

// MARK: - WebSocket Transport

/// WebSocket transport using URLSessionWebSocketTask.
/// Supports TLS, self-signed certificates, custom headers, and ping/pong keepalive.
public actor WebSocketTransport: ACPTransport {
    public let configuration: WebSocketConfiguration
    private let logger: Logger

    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var state: TransportState = .disconnected
    private var receiveContinuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var receiveTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private let ndjsonBuffer = NDJSONBuffer()
    private var sessionDelegate: WebSocketSessionDelegate?

    public var isConnected: Bool {
        state == .connected
    }

    public init(configuration: WebSocketConfiguration, logger: Logger? = nil) {
        self.configuration = configuration
        self.logger = logger ?? Logger(label: "acp.transport.websocket")
    }

    // MARK: - Connect

    public func connect() async throws {
        guard case .disconnected = state else {
            logger.warning("Already connected or connecting")
            return
        }

        state = .connecting

        guard let url = URL(string: configuration.url) else {
            state = .error("Invalid URL: \(configuration.url)")
            throw ACPError.transportError("Invalid URL: \(configuration.url)")
        }

        let delegate = WebSocketSessionDelegate(
            allowSelfSigned: configuration.allowSelfSignedCertificates,
            pinnedCertificateData: configuration.pinnedCertificateData
        )
        self.sessionDelegate = delegate

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.connectionTimeout
        sessionConfig.timeoutIntervalForResource = 0 // no resource timeout for long-lived connections

        let session = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)
        self.urlSession = session

        var request = URLRequest(url: url)
        for (key, value) in configuration.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let task = session.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()

        // Wait briefly for the connection to establish
        try await Task.sleep(for: .milliseconds(100))
        state = .connected
        logger.info("WebSocket connected to \(configuration.url)")

        startReceiveLoop()
        if configuration.heartbeatInterval > 0 {
            startHeartbeat()
        }
    }

    // MARK: - Disconnect

    public func disconnect() async {
        state = .disconnected
        heartbeatTask?.cancel()
        heartbeatTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        receiveContinuation?.finish()
        receiveContinuation = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        sessionDelegate = nil
        ndjsonBuffer.reset()
        logger.info("WebSocket disconnected")
    }

    // MARK: - Send

    public func send(_ data: Data) async throws {
        guard let task = webSocketTask, state == .connected else {
            throw ACPError.notConnected
        }
        let message = URLSessionWebSocketTask.Message.string(String(data: data, encoding: .utf8) ?? "")
        try await task.send(message)
    }

    // MARK: - Receive

    public func receive() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            self.receiveContinuation = continuation
        }
    }

    // MARK: - Private

    private func startReceiveLoop() {
        receiveTask = Task {
            while !Task.isCancelled {
                do {
                    guard let task = self.webSocketTask else { break }
                    let message = try await task.receive()
                    let data: Data
                    switch message {
                    case .string(let text):
                        data = Data(text.utf8)
                    case .data(let d):
                        data = d
                    @unknown default:
                        continue
                    }

                    let lines = self.processIncoming(data)
                    for line in lines {
                        self.yieldLine(line)
                    }
                } catch {
                    self.handleReceiveError(error)
                    break
                }
            }
        }
    }

    private func processIncoming(_ data: Data) -> [Data] {
        ndjsonBuffer.append(data)
    }

    private func yieldLine(_ line: Data) {
        receiveContinuation?.yield(line)
    }

    private func handleReceiveError(_ error: Error) {
        if !Task.isCancelled {
            logger.error("WebSocket receive error: \(error)")
            state = .error(error.localizedDescription)
            receiveContinuation?.finish(throwing: error)
        }
    }

    private func startHeartbeat() {
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.configuration.heartbeatInterval))
                guard let task = self.webSocketTask else { break }
                task.sendPing { error in
                    if let error {
                        Task {
                            await self.handleReceiveError(error)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Configuration

public struct WebSocketConfiguration: Sendable {
    public let url: String
    public let headers: [String: String]
    public let allowSelfSignedCertificates: Bool
    public let pinnedCertificateData: Data?
    public let connectionTimeout: TimeInterval
    public let heartbeatInterval: TimeInterval

    public init(
        url: String,
        headers: [String: String] = [:],
        allowSelfSignedCertificates: Bool = false,
        pinnedCertificateData: Data? = nil,
        connectionTimeout: TimeInterval = 30,
        heartbeatInterval: TimeInterval = 30
    ) {
        self.url = url
        self.headers = headers
        self.allowSelfSignedCertificates = allowSelfSignedCertificates
        self.pinnedCertificateData = pinnedCertificateData
        self.connectionTimeout = connectionTimeout
        self.heartbeatInterval = heartbeatInterval
    }
}

// MARK: - URLSession Delegate

private final class WebSocketSessionDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    let allowSelfSigned: Bool
    let pinnedCertificateData: Data?

    init(allowSelfSigned: Bool, pinnedCertificateData: Data?) {
        self.allowSelfSigned = allowSelfSigned
        self.pinnedCertificateData = pinnedCertificateData
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }

        if allowSelfSigned {
            return (.useCredential, URLCredential(trust: serverTrust))
        }

        if let pinnedData = pinnedCertificateData {
            if let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
               let serverCert = chain.first {
                let serverData = SecCertificateCopyData(serverCert) as Data
                if serverData == pinnedData {
                    return (.useCredential, URLCredential(trust: serverTrust))
                }
            }
        }

        return (.performDefaultHandling, nil)
    }
}
