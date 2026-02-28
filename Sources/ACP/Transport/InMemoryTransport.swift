import Foundation

// MARK: - In-Memory Transport

/// A bidirectional in-memory transport for testing.
/// Messages sent on one side are received on the other.
public actor InMemoryTransport: ACPTransport {
    private var connected = false
    private var receiveContinuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var peer: InMemoryTransport?
    private var pendingMessages: [Data] = []

    public var isConnected: Bool { connected }

    public init() {}

    /// Create a linked pair of in-memory transports.
    /// Messages sent on `client` are received by `server` and vice versa.
    public static func createPair() async -> (client: InMemoryTransport, server: InMemoryTransport) {
        let client = InMemoryTransport()
        let server = InMemoryTransport()
        await client.setPeer(server)
        await server.setPeer(client)
        return (client, server)
    }

    func setPeer(_ peer: InMemoryTransport) {
        self.peer = peer
    }

    public func connect() async throws {
        connected = true
        // Flush any messages that were sent before connection
        for msg in pendingMessages {
            receiveContinuation?.yield(msg)
        }
        pendingMessages.removeAll()
    }

    public func disconnect() async {
        connected = false
        receiveContinuation?.finish()
        receiveContinuation = nil
    }

    public func send(_ data: Data) async throws {
        guard connected else { throw ACPError.notConnected }
        await peer?.deliver(data)
    }

    public func receive() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            self.receiveContinuation = continuation
            // Flush any messages received before stream was created
            for msg in self.pendingMessages {
                continuation.yield(msg)
            }
            self.pendingMessages.removeAll()
        }
    }

    /// Called by the peer to deliver a message to this transport.
    func deliver(_ data: Data) {
        if let cont = receiveContinuation {
            cont.yield(data)
        } else {
            pendingMessages.append(data)
        }
    }
}
