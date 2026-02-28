#if canImport(Foundation)
import Foundation
#endif

// MARK: - Transport Protocol

/// A transport layer for sending and receiving raw data.
/// All transports are actors for thread-safe state management.
public protocol ACPTransport: Actor, Sendable {
    /// Connect to the remote endpoint.
    func connect() async throws

    /// Disconnect gracefully.
    func disconnect() async

    /// Whether the transport is currently connected.
    var isConnected: Bool { get async }

    /// Send raw data (a single NDJSON line).
    func send(_ data: Data) async throws

    /// Receive stream of raw data messages.
    func receive() -> AsyncThrowingStream<Data, Error>
}

// MARK: - Transport State

/// Connection state for transports.
public enum TransportState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)
}
