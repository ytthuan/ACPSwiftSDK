import Testing
import Foundation
@testable import ACP

// MARK: - End-to-End Tests

/// Simulates a full ACP conversation flow using InMemoryTransport:
/// ACPClient ↔ InMemoryTransport pair ↔ Mock ACP Server

@Suite("End-to-End ACP Flow")
struct EndToEndTests {

    // MARK: - Mock Server

    /// A minimal mock ACP server that handles initialize, session/new, session/prompt, and session/update.
    actor MockACPServer {
        private let transport: InMemoryTransport
        private let codec = NDJSONCodec.shared
        private var loopTask: Task<Void, Never>?

        init(transport: InMemoryTransport) {
            self.transport = transport
        }

        func start() {
            loopTask = Task {
                let stream = await transport.receive()
                do {
                    for try await data in stream {
                        guard !Task.isCancelled else { break }
                        await handleMessage(data)
                    }
                } catch {
                    // Stream ended
                }
            }
        }

        func stop() {
            loopTask?.cancel()
            loopTask = nil
        }

        private func handleMessage(_ data: Data) async {
            guard let raw = try? codec.decodeRaw(from: data) else { return }
            guard raw.isRequest, let method = raw.method, let id = raw.id else {
                // Ignore notifications
                return
            }

            switch method {
            case "initialize":
                let result: Value = [
                    "protocolVersion": 1,
                    "agentInfo": ["name": "MockAgent", "version": "1.0"],
                    "agentCapabilities": [:]
                ]
                let response = JSONRPCResponse(id: id, result: result)
                if let encoded = try? codec.encode(response) {
                    try? await transport.send(encoded)
                }

            case "session/new":
                let result: Value = [
                    "sessionId": "mock_session_001",
                    "modes": [["slug": "agent", "name": "Agent"], ["slug": "ask", "name": "Ask"]],
                    "currentMode": "agent"
                ]
                let response = JSONRPCResponse(id: id, result: result)
                if let encoded = try? codec.encode(response) {
                    try? await transport.send(encoded)
                }

                // Send available_commands_update notification
                let cmdsNotif: Value = [
                    "sessionId": "mock_session_001",
                    "sessionUpdate": "available_commands_update",
                    "availableCommands": [
                        ["name": "web", "description": "Search the web"],
                        ["name": "test", "description": "Run tests"]
                    ]
                ]
                let notif = JSONRPCNotification(method: "session/update", params: cmdsNotif)
                if let encoded = try? codec.encode(notif) {
                    try? await transport.send(encoded)
                }

            case "session/prompt":
                // Send a stream of session updates then the response

                // 1. thought_message_chunk
                let thought: Value = [
                    "sessionId": "mock_session_001",
                    "sessionUpdate": "thought_message_chunk",
                    "thought": "Let me think about this..."
                ]
                let thoughtNotif = JSONRPCNotification(method: "session/update", params: thought)
                if let encoded = try? codec.encode(thoughtNotif) {
                    try? await transport.send(encoded)
                }

                // 2. tool_call
                let toolCall: Value = [
                    "sessionId": "mock_session_001",
                    "sessionUpdate": "tool_call",
                    "toolCall": [
                        "id": "tc_001",
                        "title": "bash",
                        "kind": "execute",
                        "status": "in_progress"
                    ]
                ]
                let toolNotif = JSONRPCNotification(method: "session/update", params: toolCall)
                if let encoded = try? codec.encode(toolNotif) {
                    try? await transport.send(encoded)
                }

                // 3. tool_call_update (completed)
                let toolUpdate: Value = [
                    "sessionId": "mock_session_001",
                    "sessionUpdate": "tool_call_update",
                    "toolCallUpdate": [
                        "id": "tc_001",
                        "status": "completed",
                        "content": [["type": "content", "content": "echo done"]]
                    ]
                ]
                let toolUpdateNotif = JSONRPCNotification(method: "session/update", params: toolUpdate)
                if let encoded = try? codec.encode(toolUpdateNotif) {
                    try? await transport.send(encoded)
                }

                // 4. agent_message_chunk
                let msg: Value = [
                    "sessionId": "mock_session_001",
                    "sessionUpdate": "agent_message_chunk",
                    "delta": "Hello from MockAgent!"
                ]
                let msgNotif = JSONRPCNotification(method: "session/update", params: msg)
                if let encoded = try? codec.encode(msgNotif) {
                    try? await transport.send(encoded)
                }

                // 5. Prompt response
                let result: Value = [
                    "sessionId": "mock_session_001",
                    "stopReason": "end_turn"
                ]
                let response = JSONRPCResponse(id: id, result: result)
                if let encoded = try? codec.encode(response) {
                    try? await transport.send(encoded)
                }

            case "session/set_mode":
                let result: Value = [
                    "sessionId": "mock_session_001",
                    "currentMode": "ask"
                ]
                let response = JSONRPCResponse(id: id, result: result)
                if let encoded = try? codec.encode(response) {
                    try? await transport.send(encoded)
                }

            default:
                // Unknown method — send error
                let errResponse = JSONRPCErrorResponse(
                    id: id,
                    error: JSONRPCError.methodNotFound(method)
                )
                if let encoded = try? codec.encode(errResponse) {
                    try? await transport.send(encoded)
                }
            }
        }
    }

    // MARK: - Update Collector (Sendable-safe)

    actor UpdateCollector {
        var updates: [(String, SessionUpdate)] = []

        func add(sessionId: String, update: SessionUpdate) {
            updates.append((sessionId, update))
        }
    }

    // MARK: - Tests

    @Test("Full initialize → newSession → prompt → disconnect flow")
    func fullConversationFlow() async throws {
        let (clientTransport, serverTransport) = await InMemoryTransport.createPair()

        // Start mock server
        let server = MockACPServer(transport: serverTransport)
        try await serverTransport.connect()
        await server.start()

        // Collect session updates
        let collector = UpdateCollector()

        // Create client
        let client = ACPClient(name: "TestClient", version: "1.0")

        // Register session update handler before connecting
        await client.onSessionUpdate { sessionId, update in
            await collector.add(sessionId: sessionId, update: update)
        }

        // Connect (performs initialize handshake)
        let initResult = try await client.connect(transport: clientTransport)
        #expect(initResult.agentInfo?.name == "MockAgent")

        // Create session
        let sessionResult = try await client.newSession()
        #expect(sessionResult.sessionId == "mock_session_001")

        let sessionId = await client.sessionId
        #expect(sessionId == "mock_session_001")

        // Give time for available_commands_update notification to arrive
        try await Task.sleep(for: .milliseconds(50))

        // Send prompt
        let promptResult = try await client.prompt(text: "Hello!")
        #expect(promptResult.stopReason == .endTurn)

        // Give time for all notifications to be processed
        try await Task.sleep(for: .milliseconds(100))

        // Verify session updates arrived
        let updates = await collector.updates

        // We should have received: available_commands_update, thought_message_chunk, tool_call, tool_call_update, agent_message_chunk
        #expect(updates.count >= 4, "Expected at least 4 session updates, got \(updates.count)")

        // Check for thought chunk
        let hasThought = updates.contains { _, update in
            if case .thoughtMessageChunk(let chunk) = update {
                return chunk.thought == "Let me think about this..."
            }
            return false
        }
        #expect(hasThought, "Expected thought_message_chunk update")

        // Check for tool call
        let hasToolCall = updates.contains { _, update in
            if case .toolCall(let tc) = update {
                return tc.id == "tc_001" && tc.title == "bash"
            }
            return false
        }
        #expect(hasToolCall, "Expected tool_call update")

        // Check for agent message
        let hasAgentMsg = updates.contains { _, update in
            if case .agentMessageChunk(let chunk) = update {
                return chunk.delta == "Hello from MockAgent!"
            }
            return false
        }
        #expect(hasAgentMsg, "Expected agent_message_chunk update")

        // Disconnect
        await client.disconnect()
        await server.stop()
    }

    @Test("Set mode succeeds")
    func setMode() async throws {
        let (clientTransport, serverTransport) = await InMemoryTransport.createPair()
        let server = MockACPServer(transport: serverTransport)
        try await serverTransport.connect()
        await server.start()

        let client = ACPClient(name: "TestClient", version: "1.0")
        _ = try await client.connect(transport: clientTransport)
        _ = try await client.newSession()

        // setMode returns empty result — just verify it doesn't throw
        _ = try await client.setMode("ask")

        await client.disconnect()
        await server.stop()
    }

    @Test("Client reports connected state")
    func connectionState() async throws {
        let (clientTransport, serverTransport) = await InMemoryTransport.createPair()
        let server = MockACPServer(transport: serverTransport)
        try await serverTransport.connect()
        await server.start()

        let client = ACPClient(name: "TestClient", version: "1.0")
        let connected1 = await client.isConnected
        #expect(!connected1)

        _ = try await client.connect(transport: clientTransport)
        let connected2 = await client.isConnected
        #expect(connected2)

        await client.disconnect()
        let connected3 = await client.isConnected
        #expect(!connected3)

        await server.stop()
    }
}
