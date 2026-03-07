import Foundation
import Logging

// MARK: - ACP Client

/// The main ACP client actor. Manages transport lifecycle, JSON-RPC request/response
/// matching, notification dispatch, and high-level ACP methods.
public actor ACPClient {
    // MARK: - Configuration

    public nonisolated let clientInfo: ClientInfo
    public nonisolated let clientCapabilities: ClientCapabilities?
    private let logger: Logger
    private let idGenerator = IDGenerator()
    private let codec = NDJSONCodec.shared

    // MARK: - State

    private var transport: (any ACPTransport)?
    private var messageLoopTask: Task<Void, Never>?
    private var agentInfo: AgentInfo?
    private var agentCapabilities: AgentCapabilities?

    // Pending request tracking: id → resolver closure
    private var pendingResolvers: [String: @Sendable (Data?, JSONRPCError?) -> Void] = [:]

    // Notification handlers: method name → [handler]
    private var notificationHandlers: [String: [@Sendable (Data) async throws -> Void]] = [:]

    // Request handlers: method name → handler (for agent → client requests)
    private var requestHandlers: [String: @Sendable (JSONRPCID, Data) async throws -> Data] = [:]

    // Session state
    private var currentSessionId: String?
    private var configOptions: [ConfigOption] = []
    private var modes: [SessionMode] = []
    private var currentMode: String?

    // MARK: - Init

    public init(
        name: String,
        version: String,
        capabilities: ClientCapabilities? = nil,
        logger: Logger? = nil
    ) {
        self.clientInfo = ClientInfo(name: name, version: version)
        self.clientCapabilities = capabilities
        self.logger = logger ?? Logger(label: "acp.client")
    }

    // MARK: - Public Properties

    public var isConnected: Bool {
        get async {
            guard let transport else { return false }
            return await transport.isConnected
        }
    }

    public var sessionId: String? { currentSessionId }
    public var agent: AgentInfo? { agentInfo }
    public var capabilities: AgentCapabilities? { agentCapabilities }
    public var sessionConfigOptions: [ConfigOption] { configOptions }
    public var sessionModes: [SessionMode] { modes }
    public var sessionCurrentMode: String? { currentMode }

    /// Switch the active session without making a network call.
    /// Use this when navigating between previously-created sessions.
    public func setActiveSession(_ sessionId: String) {
        currentSessionId = sessionId
    }

    // MARK: - Connect

    /// Connect to an ACP agent via the given transport.
    /// Performs the `initialize` → `initialized` handshake.
    @discardableResult
    public func connect(transport: any ACPTransport) async throws -> Initialize.Result {
        self.transport = transport
        try await transport.connect()

        startMessageLoop()

        // Send initialize request
        let params = Initialize.Parameters(
            protocolVersion: 1,
            clientInfo: clientInfo,
            clientCapabilities: clientCapabilities
        )

        let result: Initialize.Result = try await sendRequest(method: Initialize.name, params: params)
        self.agentInfo = result.agentInfo
        self.agentCapabilities = result.agentCapabilities

        // Send initialized notification
        try await sendNotification(method: Initialized.name, params: Initialized.Parameters())

        logger.info("ACP initialized with agent: \(result.agentInfo?.name ?? "unknown")")
        return result
    }

    /// Disconnect from the agent.
    public func disconnect() async {
        messageLoopTask?.cancel()
        messageLoopTask = nil

        // Cancel all pending requests
        for (_, resolver) in pendingResolvers {
            resolver(nil, JSONRPCError.internalError("Connection closed"))
        }
        pendingResolvers.removeAll()

        await transport?.disconnect()
        transport = nil
        agentInfo = nil
        agentCapabilities = nil
        currentSessionId = nil
        configOptions = []
        modes = []
        currentMode = nil
        logger.info("ACP client disconnected")
    }

    // MARK: - High-Level Methods

    /// Create a new session.
    public func newSession(cwd: String? = nil, mcpServers: [MCPServerConfig] = []) async throws -> SessionNew.Result {
        let params = SessionNew.Parameters(cwd: cwd, mcpServers: mcpServers)
        let result: SessionNew.Result = try await sendRequest(method: SessionNew.name, params: params)
        currentSessionId = result.sessionId
        if let opts = result.configOptions { configOptions = opts }
        if let m = result.modes?.availableModes { modes = m }
        currentMode = result.modes?.currentModeId
        logger.info("Session created: \(result.sessionId)")
        return result
    }

    /// Load an existing session.
    public func loadSession(sessionId: String, cwd: String? = nil, mcpServers: [MCPServerConfig] = []) async throws -> SessionLoad.Result {
        let params = SessionLoad.Parameters(sessionId: sessionId, cwd: cwd, mcpServers: mcpServers)
        let result: SessionLoad.Result = try await sendRequest(method: SessionLoad.name, params: params)
        currentSessionId = result.sessionId ?? sessionId
        if let opts = result.configOptions { configOptions = opts }
        if let m = result.modes?.availableModes { modes = m }
        currentMode = result.modes?.currentModeId
        logger.info("Session loaded: \(result.sessionId ?? sessionId)")
        return result
    }

    /// Send a prompt to the agent. Returns when the agent completes the turn.
    /// Session updates are delivered via registered notification handlers.
    public func prompt(text: String) async throws -> SessionPrompt.Result {
        guard let sessionId = currentSessionId else {
            throw ACPError.notConnected
        }
        return try await prompt(sessionId: sessionId, content: [.text(text)])
    }

    /// Send a prompt with custom content blocks.
    public func prompt(sessionId: String, content: [ContentBlock]) async throws -> SessionPrompt.Result {
        let params = SessionPrompt.Parameters(sessionId: sessionId, prompt: content)
        return try await sendRequest(method: SessionPrompt.name, params: params)
    }

    /// Cancel the current prompt turn.
    public func cancel() async throws {
        guard let sessionId = currentSessionId else { return }
        try await sendNotification(method: SessionCancel.name, params: SessionCancel.Parameters(sessionId: sessionId))
    }

    /// Set the session mode (e.g., "agent", "edit", "ask").
    public func setMode(_ mode: String) async throws -> SessionSetMode.Result {
        guard let sessionId = currentSessionId else {
            throw ACPError.notConnected
        }
        let params = SessionSetMode.Parameters(sessionId: sessionId, mode: mode)
        return try await sendRequest(method: SessionSetMode.name, params: params)
    }

    /// Set a config option (e.g., model, mode, thinking level).
    public func setConfigOption(configId: String, value: String) async throws -> SessionSetConfigOption.Result {
        guard let sessionId = currentSessionId else {
            throw ACPError.notConnected
        }
        let params = SessionSetConfigOption.Parameters(sessionId: sessionId, configId: configId, value: value)
        return try await sendRequest(method: SessionSetConfigOption.name, params: params)
    }

    /// List sessions (RFD — requires agent support).
    public func listSessions() async throws -> SessionList.Result {
        return try await sendRequest(method: SessionList.name, params: SessionList.Parameters())
    }

    /// Delete a session (RFD — requires agent support).
    public func deleteSession(sessionId: String) async throws -> SessionDelete.Result {
        let params = SessionDelete.Parameters(sessionId: sessionId)
        return try await sendRequest(method: SessionDelete.name, params: params)
    }

    /// List available tools in the current session.
    public func listTools(sessionId: String? = nil) async throws -> ToolsList.Result {
        let sid = sessionId ?? self.sessionId
        return try await sendRequest(
            method: ToolsList.name,
            params: ToolsList.Parameters(sessionId: sid)
        )
    }

    /// Authenticate with the agent using a specific auth method.
    public func authenticate(methodId: String) async throws -> Authenticate.Result {
        try await sendRequest(method: Authenticate.name, params: Authenticate.Parameters(methodId: methodId))
    }

    // MARK: - Handler Registration

    /// Register a handler for session updates.
    public func onSessionUpdate(_ handler: @escaping @Sendable (String, SessionUpdate) async -> Void) {
        onRawNotification(SessionUpdateNotification.name) { [weak self] data in
            do {
                let (sessionId, update) = try SessionUpdate.parse(from: data)
                await handler(sessionId, update)
            } catch {
                self?.logger.error("Failed to parse session update: \(error). Data: \(String(data: data.prefix(200), encoding: .utf8) ?? "?")")
            }
        }
    }

    /// Register a handler for raw notifications by method name.
    public func onRawNotification(_ method: String, handler: @escaping @Sendable (Data) async throws -> Void) {
        notificationHandlers[method, default: []].append(handler)
    }

    /// Register a handler for agent → client requests (e.g., permission requests).
    public func onRequest(_ method: String, handler: @escaping @Sendable (JSONRPCID, Data) async throws -> Data) {
        requestHandlers[method] = handler
    }

    /// Register a typed permission request handler.
    public func onPermissionRequest(_ handler: @escaping @Sendable (JSONRPCID, RequestPermission.Parameters) async throws -> RequestPermission.Result) {
        onRequest(RequestPermission.name) { id, data in
            let decoder = JSONDecoder()
            let request = try decoder.decode(JSONRPCRequest<RequestPermission.Parameters>.self, from: data)
            guard let params = request.params else {
                throw ACPError.decodingError("Missing params in permission request")
            }
            let result = try await handler(id, params)
            let response = JSONRPCResponse(id: id, result: result)
            return try JSONEncoder().encode(response)
        }
    }

    /// Register a typed elicitation request handler.
    /// The agent sends `elicitation/create` to request structured input from the user.
    public func onElicitationRequest(_ handler: @escaping @Sendable (JSONRPCID, Elicitation.Parameters) async throws -> Elicitation.Result) {
        onRequest(Elicitation.name) { id, data in
            let decoder = JSONDecoder()
            let request = try decoder.decode(JSONRPCRequest<Elicitation.Parameters>.self, from: data)
            guard let params = request.params else {
                throw ACPError.decodingError("Missing params in elicitation request")
            }
            let result = try await handler(id, params)
            let response = JSONRPCResponse(id: id, result: result)
            return try JSONEncoder().encode(response)
        }
    }

    /// Register a handler for `terminal/create` requests from the agent.
    public func onCreateTerminal(_ handler: @escaping @Sendable (CreateTerminal.Parameters) async throws -> CreateTerminal.Result) {
        onRequest(CreateTerminal.name) { [codec] id, data in
            let wrapper = try JSONDecoder().decode(JSONRPCRequest<CreateTerminal.Parameters>.self, from: data)
            guard let params = wrapper.params else {
                throw ACPError.decodingError("Missing params in terminal/create request")
            }
            let result = try await handler(params)
            let response = JSONRPCResponse(id: id, result: result)
            return try codec.encode(response)
        }
    }

    /// Register a handler for `terminal/output` requests from the agent.
    public func onTerminalOutput(_ handler: @escaping @Sendable (TerminalOutput.Parameters) async throws -> TerminalOutput.Result) {
        onRequest(TerminalOutput.name) { [codec] id, data in
            let wrapper = try JSONDecoder().decode(JSONRPCRequest<TerminalOutput.Parameters>.self, from: data)
            guard let params = wrapper.params else {
                throw ACPError.decodingError("Missing params in terminal/output request")
            }
            let result = try await handler(params)
            let response = JSONRPCResponse(id: id, result: result)
            return try codec.encode(response)
        }
    }

    /// Register a handler for `terminal/wait_for_exit` requests from the agent.
    public func onWaitForTerminalExit(_ handler: @escaping @Sendable (WaitForTerminalExit.Parameters) async throws -> WaitForTerminalExit.Result) {
        onRequest(WaitForTerminalExit.name) { [codec] id, data in
            let wrapper = try JSONDecoder().decode(JSONRPCRequest<WaitForTerminalExit.Parameters>.self, from: data)
            guard let params = wrapper.params else {
                throw ACPError.decodingError("Missing params in terminal/wait_for_exit request")
            }
            let result = try await handler(params)
            let response = JSONRPCResponse(id: id, result: result)
            return try codec.encode(response)
        }
    }

    /// Register a handler for `terminal/kill` requests from the agent.
    public func onKillTerminal(_ handler: @escaping @Sendable (KillTerminal.Parameters) async throws -> KillTerminal.Result) {
        onRequest(KillTerminal.name) { [codec] id, data in
            let wrapper = try JSONDecoder().decode(JSONRPCRequest<KillTerminal.Parameters>.self, from: data)
            guard let params = wrapper.params else {
                throw ACPError.decodingError("Missing params in terminal/kill request")
            }
            let result = try await handler(params)
            let response = JSONRPCResponse(id: id, result: result)
            return try codec.encode(response)
        }
    }

    /// Register a handler for `terminal/release` requests from the agent.
    public func onReleaseTerminal(_ handler: @escaping @Sendable (ReleaseTerminal.Parameters) async throws -> ReleaseTerminal.Result) {
        onRequest(ReleaseTerminal.name) { [codec] id, data in
            let wrapper = try JSONDecoder().decode(JSONRPCRequest<ReleaseTerminal.Parameters>.self, from: data)
            guard let params = wrapper.params else {
                throw ACPError.decodingError("Missing params in terminal/release request")
            }
            let result = try await handler(params)
            let response = JSONRPCResponse(id: id, result: result)
            return try codec.encode(response)
        }
    }

    /// Register handler for agent's fs/read_text_file requests.
    public func onReadTextFile(_ handler: @escaping @Sendable (ReadTextFile.Parameters) async throws -> ReadTextFile.Result) {
        onRequest(ReadTextFile.name) { [codec] id, data in
            let wrapper = try JSONDecoder().decode(JSONRPCRequest<ReadTextFile.Parameters>.self, from: data)
            guard let params = wrapper.params else {
                throw ACPError.decodingError("Missing params in read_text_file request")
            }
            let result = try await handler(params)
            let response = JSONRPCResponse(id: id, result: result)
            return try codec.encode(response)
        }
    }

    /// Register handler for agent's fs/write_text_file requests.
    public func onWriteTextFile(_ handler: @escaping @Sendable (WriteTextFile.Parameters) async throws -> WriteTextFile.Result) {
        onRequest(WriteTextFile.name) { [codec] id, data in
            let wrapper = try JSONDecoder().decode(JSONRPCRequest<WriteTextFile.Parameters>.self, from: data)
            guard let params = wrapper.params else {
                throw ACPError.decodingError("Missing params in write_text_file request")
            }
            let result = try await handler(params)
            let response = JSONRPCResponse(id: id, result: result)
            return try codec.encode(response)
        }
    }

    /// Register a handler for `exitPlanMode.request` requests from the agent.
    public func onExitPlanModeRequest(_ handler: @escaping @Sendable (JSONRPCID, ExitPlanMode.Parameters) async throws -> ExitPlanMode.Result) {
        onRequest(ExitPlanMode.name) { [codec] id, data in
            let wrapper = try JSONDecoder().decode(JSONRPCRequest<ExitPlanMode.Parameters>.self, from: data)
            guard let params = wrapper.params else {
                throw ACPError.decodingError("Missing params in exitPlanMode.request")
            }
            let result = try await handler(id, params)
            let response = JSONRPCResponse(id: id, result: result)
            return try codec.encode(response)
        }
    }

    // MARK: - Low-Level Send

    /// Send a typed request and wait for the response.
    public func sendRequest<Params: Codable & Hashable & Sendable, Result: Codable & Hashable & Sendable>(
        method: String,
        params: Params
    ) async throws -> Result {
        guard let transport else { throw ACPError.notConnected }

        let id = idGenerator.next()
        let request = JSONRPCRequest(id: id, method: method, params: params)
        let data = try codec.encode(request)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Result, Error>) in
            let resolver: @Sendable (Data?, JSONRPCError?) -> Void = { responseData, rpcError in
                if let rpcError {
                    continuation.resume(throwing: ACPError.requestFailed(rpcError))
                    return
                }
                guard let responseData else {
                    continuation.resume(throwing: ACPError.decodingError("Empty response"))
                    return
                }
                do {
                    // Decode the full JSON-RPC response to extract the result field
                    let response = try JSONDecoder().decode(JSONRPCResponse<Result>.self, from: responseData)
                    continuation.resume(returning: response.result)
                } catch {
                    continuation.resume(throwing: ACPError.decodingError("Failed to decode response: \(error)"))
                }
            }

            self.pendingResolvers[id.stringValue] = resolver

            Task {
                do {
                    try await transport.send(data)
                } catch {
                    self.pendingResolvers.removeValue(forKey: id.stringValue)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Send a notification (no response expected).
    public func sendNotification<Params: Codable & Hashable & Sendable>(
        method: String,
        params: Params
    ) async throws {
        guard let transport else { throw ACPError.notConnected }
        let notification = JSONRPCNotification(method: method, params: params)
        let data = try codec.encode(notification)
        try await transport.send(data)
    }

    // MARK: - Message Loop

    private func startMessageLoop() {
        guard let transport else { return }

        messageLoopTask = Task {
            let stream = await transport.receive()
            do {
                for try await data in stream {
                    guard !Task.isCancelled else { break }
                    await self.handleMessage(data)
                }
            } catch {
                self.logger.error("Message loop error: \(error)")
            }
        }
    }

    private func handleMessage(_ data: Data) async {
        do {
            let raw = try codec.decodeRaw(from: data)

            if raw.isResponse {
                handleResponse(raw, data: data)
            } else if raw.isRequest {
                await handleIncomingRequest(raw, data: data)
            } else if raw.isNotification {
                logger.debug("Notification received: \(raw.method ?? "?")")
                await handleNotification(raw, data: data)
            } else {
                logger.warning("Unknown message format: \(String(data: data.prefix(100), encoding: .utf8) ?? "?")")
            }
        } catch {
            logger.error("Failed to decode message: \(error)")
        }
    }

    private func handleResponse(_ raw: RawMessage, data: Data) {
        guard let id = raw.id else { return }
        guard let resolver = pendingResolvers.removeValue(forKey: id.stringValue) else {
            logger.warning("No pending request for id: \(id.stringValue)")
            return
        }

        if let error = raw.error {
            resolver(nil, error)
        } else {
            resolver(data, nil)
        }
    }

    private func handleIncomingRequest(_ raw: RawMessage, data: Data) async {
        guard let method = raw.method, let id = raw.id else { return }

        if let handler = requestHandlers[method] {
            do {
                let responseData = try await handler(id, data)
                try await transport?.send(responseData)
            } catch {
                logger.error("Request handler error for \(method): \(error)")
                let errResponse = JSONRPCErrorResponse(
                    id: id,
                    error: JSONRPCError.internalError(String(describing: error))
                )
                do {
                    let data = try codec.encode(errResponse)
                    try await transport?.send(data)
                } catch {
                    logger.error("Failed to send error response: \(error)")
                }
            }
        } else {
            logger.warning("No handler for request: \(method)")
            let errResponse = JSONRPCErrorResponse(
                id: id,
                error: JSONRPCError.methodNotFound(method)
            )
            do {
                let data = try codec.encode(errResponse)
                try await transport?.send(data)
            } catch {
                logger.error("Failed to send error response: \(error)")
            }
        }
    }

    private func handleNotification(_ raw: RawMessage, data: Data) async {
        guard let method = raw.method else { return }

        if let handlers = notificationHandlers[method] {
            for handler in handlers {
                try? await handler(data)
            }
        }
    }
}
