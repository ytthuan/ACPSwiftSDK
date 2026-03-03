import Foundation
import Testing
@testable import ACP

@Suite("Terminal Handler Missing Params")
struct TerminalHandlerMissingParamsTests {
    actor CallTracker {
        private(set) var count = 0

        func markCalled() {
            count += 1
        }
    }

    @Test("onCreateTerminal missing params returns decoding error and does not call handler")
    func onCreateTerminalMissingParams() async throws {
        let tracker = CallTracker()
        let (client, serverTransport, initialIterator) = try await makeConnectedClientWithServerIterator()

        await client.onCreateTerminal { _ in
            await tracker.markCalled()
            return CreateTerminal.Result(terminalId: "terminal-1")
        }

        var iterator = initialIterator
        let response = try await sendMalformedRequest(
            method: CreateTerminal.name,
            id: .int(1001),
            serverTransport: serverTransport,
            iterator: &iterator
        )

        #expect(response.id == .int(1001))
        #expect(response.error.code == JSONRPCErrorCode.internalError.rawValue)
        #expect(response.error.message.contains("Missing params in terminal/create request"))
        #expect(await tracker.count == 0)

        await client.disconnect()
        await serverTransport.disconnect()
    }

    @Test("onTerminalOutput missing params returns decoding error and does not call handler")
    func onTerminalOutputMissingParams() async throws {
        let tracker = CallTracker()
        let (client, serverTransport, initialIterator) = try await makeConnectedClientWithServerIterator()

        await client.onTerminalOutput { _ in
            await tracker.markCalled()
            return TerminalOutput.Result(output: "", truncated: false)
        }

        var iterator = initialIterator
        let response = try await sendMalformedRequest(
            method: TerminalOutput.name,
            id: .int(1002),
            serverTransport: serverTransport,
            iterator: &iterator
        )

        #expect(response.id == .int(1002))
        #expect(response.error.code == JSONRPCErrorCode.internalError.rawValue)
        #expect(response.error.message.contains("Missing params in terminal/output request"))
        #expect(await tracker.count == 0)

        await client.disconnect()
        await serverTransport.disconnect()
    }

    @Test("onWaitForTerminalExit missing params returns decoding error and does not call handler")
    func onWaitForTerminalExitMissingParams() async throws {
        let tracker = CallTracker()
        let (client, serverTransport, initialIterator) = try await makeConnectedClientWithServerIterator()

        await client.onWaitForTerminalExit { _ in
            await tracker.markCalled()
            return WaitForTerminalExit.Result(exitCode: 0)
        }

        var iterator = initialIterator
        let response = try await sendMalformedRequest(
            method: WaitForTerminalExit.name,
            id: .int(1003),
            serverTransport: serverTransport,
            iterator: &iterator
        )

        #expect(response.id == .int(1003))
        #expect(response.error.code == JSONRPCErrorCode.internalError.rawValue)
        #expect(response.error.message.contains("Missing params in terminal/wait_for_exit request"))
        #expect(await tracker.count == 0)

        await client.disconnect()
        await serverTransport.disconnect()
    }

    @Test("onKillTerminal missing params returns decoding error and does not call handler")
    func onKillTerminalMissingParams() async throws {
        let tracker = CallTracker()
        let (client, serverTransport, initialIterator) = try await makeConnectedClientWithServerIterator()

        await client.onKillTerminal { _ in
            await tracker.markCalled()
            return KillTerminal.Result()
        }

        var iterator = initialIterator
        let response = try await sendMalformedRequest(
            method: KillTerminal.name,
            id: .int(1004),
            serverTransport: serverTransport,
            iterator: &iterator
        )

        #expect(response.id == .int(1004))
        #expect(response.error.code == JSONRPCErrorCode.internalError.rawValue)
        #expect(response.error.message.contains("Missing params in terminal/kill request"))
        #expect(await tracker.count == 0)

        await client.disconnect()
        await serverTransport.disconnect()
    }

    @Test("onReleaseTerminal missing params returns decoding error and does not call handler")
    func onReleaseTerminalMissingParams() async throws {
        let tracker = CallTracker()
        let (client, serverTransport, initialIterator) = try await makeConnectedClientWithServerIterator()

        await client.onReleaseTerminal { _ in
            await tracker.markCalled()
            return ReleaseTerminal.Result()
        }

        var iterator = initialIterator
        let response = try await sendMalformedRequest(
            method: ReleaseTerminal.name,
            id: .int(1005),
            serverTransport: serverTransport,
            iterator: &iterator
        )

        #expect(response.id == .int(1005))
        #expect(response.error.code == JSONRPCErrorCode.internalError.rawValue)
        #expect(response.error.message.contains("Missing params in terminal/release request"))
        #expect(await tracker.count == 0)

        await client.disconnect()
        await serverTransport.disconnect()
    }

    private func makeConnectedClientWithServerIterator() async throws -> (
        client: ACPClient,
        serverTransport: InMemoryTransport,
        iterator: AsyncThrowingStream<Data, Error>.AsyncIterator
    ) {
        let codec = NDJSONCodec.shared
        let (clientTransport, serverTransport) = await InMemoryTransport.createPair()
        try await serverTransport.connect()

        var iterator = await serverTransport.receive().makeAsyncIterator()
        let client = ACPClient(name: "TerminalTestClient", version: "1.0")

        let connectTask = Task {
            try await client.connect(transport: clientTransport)
        }

        guard let initializeData = try await iterator.next() else {
            throw ACPError.connectionClosed
        }

        let initialize = try codec.decode(RawMessage.self, from: initializeData)
        guard initialize.method == Initialize.name, let initializeID = initialize.id else {
            throw ACPError.unexpectedResponse("Expected initialize request")
        }

        let initializeResponse: Value = ["protocolVersion": 1]
        let responseData = try codec.encode(JSONRPCResponse(id: initializeID, result: initializeResponse))
        try await serverTransport.send(responseData)

        _ = try await connectTask.value

        // Consume `initialized` notification from the client.
        _ = try await iterator.next()

        return (client, serverTransport, iterator)
    }

    private func sendMalformedRequest(
        method: String,
        id: JSONRPCID,
        serverTransport: InMemoryTransport,
        iterator: inout AsyncThrowingStream<Data, Error>.AsyncIterator
    ) async throws -> JSONRPCErrorResponse {
        let payload = "{\"jsonrpc\":\"2.0\",\"id\":\(idLiteral(id)),\"method\":\"\(method)\"}\n"
        try await serverTransport.send(Data(payload.utf8))

        guard let responseData = try await iterator.next() else {
            throw ACPError.connectionClosed
        }
        return try NDJSONCodec.shared.decode(JSONRPCErrorResponse.self, from: responseData)
    }

    private func idLiteral(_ id: JSONRPCID) -> String {
        switch id {
        case .int(let value):
            return String(value)
        case .string(let value):
            return "\"\(value)\""
        }
    }
}
