import Testing
import Foundation
@testable import ACP

// MARK: - InMemoryTransport Tests

@Suite("InMemoryTransport")
struct InMemoryTransportTests {
    @Test("Create pair and send messages")
    func pairSendReceive() async throws {
        let (clientTransport, serverTransport) = await InMemoryTransport.createPair()

        try await clientTransport.connect()
        try await serverTransport.connect()

        // Set up receive stream BEFORE sending
        let stream = await serverTransport.receive()

        let message = Data("{\"jsonrpc\":\"2.0\",\"method\":\"test\"}\n".utf8)
        try await clientTransport.send(message)

        for try await received in stream {
            let text = String(data: received, encoding: .utf8)!
            #expect(text.contains("test"))
            break
        }

        await clientTransport.disconnect()
        await serverTransport.disconnect()
    }
}

// MARK: - Session Method Types Tests

@Suite("Session Methods")
struct SessionMethodTests {
    @Test("Initialize request encodes method")
    func initializeMethod() {
        #expect(Initialize.name == "initialize")
    }

    @Test("SessionNew encodes method")
    func sessionNewMethod() {
        #expect(SessionNew.name == "session/new")
    }

    @Test("SessionPrompt encodes method")
    func sessionPromptMethod() {
        #expect(SessionPrompt.name == "session/prompt")
    }

    @Test("SessionCancel encodes method")
    func sessionCancelMethod() {
        #expect(SessionCancel.name == "session/cancel")
    }

    @Test("Initialize params encode correctly")
    func initializeParams() throws {
        let params = Initialize.Parameters(
            clientInfo: ClientInfo(name: "Remo", version: "1.0"),
            clientCapabilities: ClientCapabilities()
        )
        let data = try JSONEncoder().encode(params)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("Remo"))
    }

    @Test("SessionNew params encode correctly")
    func sessionNewParams() throws {
        let params = SessionNew.Parameters(cwd: "/tmp")
        let data = try JSONEncoder().encode(params)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("/tmp"))
    }

    @Test("SessionPrompt params with text content")
    func sessionPromptParams() throws {
        let params = SessionPrompt.Parameters(
            sessionId: "sess_123",
            prompt: [.text(TextContent(text: "Hello"))]
        )
        let data = try JSONEncoder().encode(params)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("sess_123"))
        #expect(json.contains("Hello"))
    }
}

// MARK: - SessionUpdate Parsing Tests

@Suite("SessionUpdate Parsing")
struct SessionUpdateTests {
    @Test("Parse agent_message_chunk")
    func agentMessageChunk() throws {
        let json = #"{"sessionId":"s1","sessionUpdate":"agent_message_chunk","content":[{"type":"text","text":"Hello"}]}"#
        let (sessionId, update) = try SessionUpdate.parse(from: Data(json.utf8))
        #expect(sessionId == "s1")
        if case .agentMessageChunk(let chunk) = update {
            #expect((chunk.content?.count ?? 0) == 1)
        } else {
            Issue.record("Expected agentMessageChunk")
        }
    }

    @Test("Parse tool_call")
    func toolCall() throws {
        let json = """
        {"sessionId":"s1","sessionUpdate":"tool_call","toolCall":{"id":"tc1","title":"bash","status":"in_progress","kind":"execute"}}
        """
        let (_, update) = try SessionUpdate.parse(from: Data(json.utf8))
        if case .toolCall(let tc) = update {
            #expect(tc.id == "tc1")
            #expect(tc.title == "bash")
            #expect(tc.status == .inProgress)
            #expect(tc.kind == .execute)
        } else {
            Issue.record("Expected toolCall")
        }
    }

    @Test("Parse plan")
    func plan() throws {
        let json = """
        {"sessionId":"s1","sessionUpdate":"plan","entries":[{"id":"p1","title":"Step 1","status":"completed"}]}
        """
        let (_, update) = try SessionUpdate.parse(from: Data(json.utf8))
        if case .plan(let planUpdate) = update {
            #expect(planUpdate.entries.count == 1)
            #expect(planUpdate.entries[0].title == "Step 1")
        } else {
            Issue.record("Expected plan")
        }
    }

    @Test("Parse from notification envelope")
    func notificationEnvelope() throws {
        let json = """
        {"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"s1","sessionUpdate":"agent_message_chunk","content":[{"type":"text","text":"Hi"}]}}
        """
        let (sessionId, update) = try SessionUpdate.parse(from: Data(json.utf8))
        #expect(sessionId == "s1")
        if case .agentMessageChunk(let chunk) = update {
            #expect((chunk.content?.count ?? 0) == 1)
        } else {
            Issue.record("Expected agentMessageChunk from envelope")
        }
    }

    @Test("Parse thought_message_chunk")
    func thoughtChunk() throws {
        let json = #"{"sessionId":"s1","sessionUpdate":"thought_message_chunk","thought":"Thinking..."}"#
        let (_, update) = try SessionUpdate.parse(from: Data(json.utf8))
        if case .thoughtMessageChunk(let chunk) = update {
            #expect(chunk.thought == "Thinking...")
        } else {
            Issue.record("Expected thoughtMessageChunk")
        }
    }

    @Test("Parse available_commands_update")
    func availableCommands() throws {
        let json = """
        {"sessionId":"s1","sessionUpdate":"available_commands_update","availableCommands":[{"name":"web","description":"Search"}]}
        """
        let (_, update) = try SessionUpdate.parse(from: Data(json.utf8))
        if case .availableCommandsUpdate(let update) = update {
            #expect(update.availableCommands.count == 1)
            #expect(update.availableCommands[0].name == "web")
        } else {
            Issue.record("Expected availableCommandsUpdate")
        }
    }

    @Test("Unknown update type handled gracefully")
    func unknownUpdate() throws {
        let json = #"{"sessionId":"s1","sessionUpdate":"future_type","data":{}}"#
        let (_, update) = try SessionUpdate.parse(from: Data(json.utf8))
        if case .unknown(let typeName, _) = update {
            #expect(typeName == "future_type")
        } else {
            Issue.record("Expected unknown for unrecognized type")
        }
    }
}

// MARK: - ToolCall Types Tests

@Suite("ToolCall Types")
struct ToolCallTypesTests {
    @Test("ToolKind raw values")
    func toolKindValues() {
        #expect(ToolKind.read.rawValue == "read")
        #expect(ToolKind.edit.rawValue == "edit")
        #expect(ToolKind.execute.rawValue == "execute")
        #expect(ToolKind.search.rawValue == "search")
        #expect(ToolKind.think.rawValue == "think")
    }

    @Test("ToolCallStatus raw values")
    func toolCallStatusValues() {
        #expect(ToolCallStatus.pending.rawValue == "pending")
        #expect(ToolCallStatus.inProgress.rawValue == "in_progress")
        #expect(ToolCallStatus.completed.rawValue == "completed")
        #expect(ToolCallStatus.failed.rawValue == "failed")
    }

    @Test("StopReason raw values")
    func stopReasonValues() {
        #expect(StopReason.endTurn.rawValue == "end_turn")
        #expect(StopReason.maxTokens.rawValue == "max_tokens")
        #expect(StopReason.cancelled.rawValue == "cancelled")
    }
}

// MARK: - PermissionRequest Tests

@Suite("Permission Request")
struct PermissionRequestTests {
    @Test("PermissionOption struct has id field")
    func permissionOptions() {
        let opt = PermissionOption(id: "allow_once", title: "Allow Once", description: nil, isDestructive: nil)
        #expect(opt.id == "allow_once")
        #expect(opt.title == "Allow Once")
    }
}
