import Foundation

// MARK: - Initialize

/// `initialize` method — first message from client to agent.
public enum Initialize: ACPMethod {
    public static let name = "initialize"

    public struct Parameters: Codable, Hashable, Sendable {
        public let protocolVersion: Int
        public let clientInfo: ClientInfo
        public let clientCapabilities: ClientCapabilities?

        public init(
            protocolVersion: Int = 1,
            clientInfo: ClientInfo,
            clientCapabilities: ClientCapabilities? = nil
        ) {
            self.protocolVersion = protocolVersion
            self.clientInfo = clientInfo
            self.clientCapabilities = clientCapabilities
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public let protocolVersion: Int?
        public let agentInfo: AgentInfo?
        public let agentCapabilities: AgentCapabilities?
        public let authMethods: [AuthMethod]?
    }
}

// MARK: - Auth Method

public struct AuthMethod: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let type: String?

    public init(id: String, name: String, description: String? = nil, type: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
    }
}

// MARK: - Authenticate

/// `authenticate` method — authenticate with the agent using a specific auth method.
public enum Authenticate: ACPMethod {
    public static let name = "authenticate"

    public struct Parameters: Codable, Hashable, Sendable {
        public let methodId: String

        public init(methodId: String) {
            self.methodId = methodId
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public init() {}
    }
}

/// `initialized` notification — sent by client after successful initialize.
public enum Initialized: ACPNotification {
    public static let name = "initialized"

    public struct Parameters: Codable, Hashable, Sendable {
        public init() {}
    }
}

// MARK: - Client Info

public struct ClientInfo: Codable, Hashable, Sendable {
    public let name: String
    public let title: String?
    public let version: String

    public init(name: String, title: String? = nil, version: String) {
        self.name = name
        self.title = title
        self.version = version
    }
}

public struct ClientCapabilities: Codable, Hashable, Sendable {
    public let fs: FSCapabilities?
    public let terminal: Bool?
    public let _meta: Value?

    enum CodingKeys: String, CodingKey {
        case fs, terminal, _meta
    }

    public init(fs: FSCapabilities? = nil, terminal: Bool? = nil, meta: Value? = nil) {
        self.fs = fs
        self.terminal = terminal
        self._meta = meta
    }
}

public struct FSCapabilities: Codable, Hashable, Sendable {
    public let readTextFile: Bool?
    public let writeTextFile: Bool?

    public init(readTextFile: Bool? = nil, writeTextFile: Bool? = nil) {
        self.readTextFile = readTextFile
        self.writeTextFile = writeTextFile
    }
}

// MARK: - Agent Info

public struct AgentInfo: Codable, Hashable, Sendable {
    public let name: String?
    public let title: String?
    public let version: String?
}

public struct AgentCapabilities: Codable, Hashable, Sendable {
    public let promptCapabilities: PromptCapabilities?
    public let loadSession: Bool?
    public let listSession: Bool?
    public let deleteSession: Bool?
    public let sessionCapabilities: SessionCapabilities?
    public let mcpCapabilities: MCPCapabilities?
    public let _meta: Value?

    enum CodingKeys: String, CodingKey {
        case promptCapabilities, loadSession, listSession, deleteSession
        case sessionCapabilities, mcpCapabilities, _meta
    }
}

public struct MCPCapabilities: Codable, Hashable, Sendable {
    public let http: Bool?
    public let sse: Bool?
}

public struct SessionCapabilities: Codable, Hashable, Sendable {
    public let list: SessionListCapability?
    public let delete: SessionDeleteCapability?

    public struct SessionListCapability: Codable, Hashable, Sendable {}
    public struct SessionDeleteCapability: Codable, Hashable, Sendable {}
}

public struct PromptCapabilities: Codable, Hashable, Sendable {
    public let image: Bool?
    public let audio: Bool?
    public let embeddedContext: Bool?
}

// MARK: - Session/New

public enum SessionNew: ACPMethod {
    public static let name = "session/new"

    public struct Parameters: Codable, Hashable, Sendable {
        /// The working directory for this session. Must be an absolute path.
        /// - Important: Required by the ACP specification.
        public let cwd: String?
        public let mcpServers: [MCPServerConfig]

        public init(cwd: String? = nil, mcpServers: [MCPServerConfig] = []) {
            self.cwd = cwd
            self.mcpServers = mcpServers
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public let sessionId: String
        /// Nested modes object from Copilot CLI (modes.availableModes, modes.currentModeId)
        public let modes: ModesInfo?
        /// Nested models object from Copilot CLI (models.availableModels, models.currentModelId)
        /// - Note: Copilot CLI extension, not part of the ACP specification.
        public let models: ModelsInfo?
        /// Flat config options array (ACP spec format)
        public let configOptions: [ConfigOption]?
    }
}

// MARK: - Session/Load

public enum SessionLoad: ACPMethod {
    public static let name = "session/load"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String
        public let cwd: String?
        public let mcpServers: [MCPServerConfig]

        public init(sessionId: String, cwd: String? = nil, mcpServers: [MCPServerConfig] = []) {
            self.sessionId = sessionId
            self.cwd = cwd
            self.mcpServers = mcpServers
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public let sessionId: String?
        public let modes: ModesInfo?
        public let models: ModelsInfo?
        public let configOptions: [ConfigOption]?
    }
}

// MARK: - Session/Prompt

public enum SessionPrompt: ACPMethod {
    public static let name = "session/prompt"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String
        public let prompt: [ContentBlock]

        public init(sessionId: String, prompt: [ContentBlock]) {
            self.sessionId = sessionId
            self.prompt = prompt
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public let stopReason: StopReason?
        /// - Note: Copilot CLI extension, not part of the ACP specification.
        public let usage: TokenUsage?
    }
}

// MARK: - Session/Cancel

public enum SessionCancel: ACPNotification {
    public static let name = "session/cancel"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String

        public init(sessionId: String) {
            self.sessionId = sessionId
        }
    }
}

// MARK: - Session/Set Mode

public enum SessionSetMode: ACPMethod {
    public static let name = "session/set_mode"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String
        public let modeId: String

        public init(sessionId: String, mode: String) {
            self.sessionId = sessionId
            self.modeId = mode
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public init() {}
    }
}

// MARK: - Session/Set Config Option

public enum SessionSetConfigOption: ACPMethod {
    public static let name = "session/set_config_option"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String
        public let configId: String
        public let value: String

        public init(sessionId: String, configId: String, value: String) {
            self.sessionId = sessionId
            self.configId = configId
            self.value = value
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public let configOptions: [ConfigOption]?
        public init(configOptions: [ConfigOption]? = nil) {
            self.configOptions = configOptions
        }
    }
}

// MARK: - Session/List (RFD)

/// `session/list` — list all sessions.
/// - Note: ACP RFD feature, not yet in the stable ACP specification.
public enum SessionList: ACPMethod {
    public static let name = "session/list"

    public struct Parameters: Codable, Hashable, Sendable {
        public init() {}
    }

    public struct Result: Codable, Hashable, Sendable {
        public let sessions: [SessionSummary]
    }
}

public struct SessionSummary: Codable, Hashable, Sendable {
    public let sessionId: String
    public let title: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let context: SessionContext?

    public init(
        sessionId: String,
        title: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        context: SessionContext? = nil
    ) {
        self.sessionId = sessionId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.context = context
    }
}

public struct SessionContext: Codable, Hashable, Sendable {
    public let cwd: String?
    public let repository: String?
    public let branch: String?

    public init(cwd: String? = nil, repository: String? = nil, branch: String? = nil) {
        self.cwd = cwd
        self.repository = repository
        self.branch = branch
    }
}

// MARK: - Session/Delete (RFD)

/// `session/delete` — delete a session by ID.
/// - Note: ACP RFD feature, not yet in the stable ACP specification.
public enum SessionDelete: ACPMethod {
    public static let name = "session/delete"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String

        public init(sessionId: String) {
            self.sessionId = sessionId
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public init() {}
    }
}

// MARK: - Tools List

/// `tools/list` — list available tools in the current session.
public enum ToolsList: ACPMethod {
    public static let name = "tools/list"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String?

        public init(sessionId: String? = nil) {
            self.sessionId = sessionId
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public let tools: [ToolInfo]

        public init(tools: [ToolInfo]) {
            self.tools = tools
        }
    }
}

public struct ToolInfo: Codable, Hashable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let description: String?
    public let inputSchema: Value?

    public init(name: String, description: String? = nil, inputSchema: Value? = nil) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

// MARK: - File System (Agent → Client)

/// `fs/read_text_file` — agent asks the client to read a file from the local file system.
public enum ReadTextFile: ACPMethod {
    public static let name = "fs/read_text_file"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String
        public let path: String
        public let line: Int?
        public let limit: Int?

        public init(sessionId: String, path: String, line: Int? = nil, limit: Int? = nil) {
            self.sessionId = sessionId
            self.path = path
            self.line = line
            self.limit = limit
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public let content: String

        public init(content: String) {
            self.content = content
        }
    }
}

/// `fs/write_text_file` — agent asks the client to write a file to the local file system.
public enum WriteTextFile: ACPMethod {
    public static let name = "fs/write_text_file"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String
        public let path: String
        public let content: String

        public init(sessionId: String, path: String, content: String) {
            self.sessionId = sessionId
            self.path = path
            self.content = content
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public init() {}
    }
}

// MARK: - Supporting Types

public struct MCPServerConfig: Codable, Hashable, Sendable {
    /// Transport type: `"http"` or `"sse"`. `nil` for stdio (the default).
    public let type: String?
    public let name: String?
    /// The command to launch the MCP server process (stdio transport).
    public let command: String?
    /// Arguments passed to the command (stdio transport).
    public let args: [String]?
    /// Legacy URI field retained for backward compatibility.
    public let uri: String?
    /// Server URL (http / sse transport).
    public let url: String?
    /// Environment variables passed to the server process (stdio transport).
    public let env: [EnvVariable]?
    /// HTTP headers sent when connecting (http / sse transport).
    public let headers: [HttpHeader]?

    public init(
        type: String? = nil,
        name: String? = nil,
        command: String? = nil,
        args: [String]? = nil,
        uri: String? = nil,
        url: String? = nil,
        env: [EnvVariable]? = nil,
        headers: [HttpHeader]? = nil
    ) {
        self.type = type
        self.name = name
        self.command = command
        self.args = args
        self.uri = uri
        self.url = url
        self.env = env
        self.headers = headers
    }
}

extension MCPServerConfig {
    /// Create a stdio transport config.
    public static func stdio(
        name: String,
        command: String,
        args: [String] = [],
        env: [EnvVariable] = []
    ) -> MCPServerConfig {
        MCPServerConfig(name: name, command: command, args: args, env: env)
    }

    /// Create an HTTP transport config.
    public static func http(
        name: String,
        url: String,
        headers: [HttpHeader] = []
    ) -> MCPServerConfig {
        MCPServerConfig(type: "http", name: name, url: url, headers: headers)
    }

    /// Create an SSE transport config.
    public static func sse(
        name: String,
        url: String,
        headers: [HttpHeader] = []
    ) -> MCPServerConfig {
        MCPServerConfig(type: "sse", name: name, url: url, headers: headers)
    }
}

public struct HttpHeader: Codable, Hashable, Sendable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

public struct EnvVariable: Codable, Hashable, Sendable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

// MARK: - Token Usage

/// - Note: Copilot CLI extension, not part of the ACP specification.
public struct TokenUsage: Codable, Hashable, Sendable {
    public let totalTokens: Int?
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let thoughtTokens: Int?

    enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case thoughtTokens = "thought_tokens"
    }
}

// MARK: - Stop Reason

public enum StopReason: String, Codable, Hashable, Sendable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case maxTurnRequests = "max_turn_requests"
    case refusal
    case cancelled
}

// MARK: - Session Mode

public struct SessionMode: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String?
    public let description: String?

    private enum CodingKeys: String, CodingKey {
        case id, slug, name, description
    }

    public init(id: String, name: String? = nil, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decode(String.self, forKey: .slug)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
    }
}

// MARK: - Models Info (Copilot CLI response format)

/// - Note: Copilot CLI extension, not part of the ACP specification.
public struct ModelsInfo: Codable, Hashable, Sendable {
    public let availableModels: [ModelInfo]?
    public let currentModelId: String?
}

/// - Note: Copilot CLI extension, not part of the ACP specification.
public struct ModelInfo: Codable, Hashable, Sendable, Identifiable {
    public var id: String { modelId }
    public let modelId: String
    public let name: String?
    public let description: String?
}

// MARK: - Modes Info (Copilot CLI response format)

public struct ModesInfo: Codable, Hashable, Sendable {
    public let availableModes: [SessionMode]?
    public let currentModeId: String?
}

// MARK: - Config Options

public struct ConfigOption: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String?
    public let description: String?
    public let category: ConfigCategory?
    public let type: String?
    public let currentValue: String?
    public let options: [ConfigOptionValue]?
}

public enum ConfigCategory: String, Codable, Hashable, Sendable {
    case model
    case mode
    case thoughtLevel = "thought_level"
}

public struct ConfigOptionValue: Codable, Hashable, Sendable {
    public let value: String
    public let name: String?
    public let description: String?
}

// MARK: - Terminal Methods (agent → client)

/// `terminal/create` — agent asks the client to create a terminal.
public enum CreateTerminal: ACPMethod {
    public static let name = "terminal/create"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String
        public let command: String
        public let args: [String]?
        public let env: [EnvVariable]?
        public let cwd: String?
        public let outputByteLimit: Int?

        public init(
            sessionId: String,
            command: String,
            args: [String]? = nil,
            env: [EnvVariable]? = nil,
            cwd: String? = nil,
            outputByteLimit: Int? = nil
        ) {
            self.sessionId = sessionId
            self.command = command
            self.args = args
            self.env = env
            self.cwd = cwd
            self.outputByteLimit = outputByteLimit
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public let terminalId: String

        public init(terminalId: String) {
            self.terminalId = terminalId
        }
    }
}

/// `terminal/output` — agent asks the client for terminal output.
public enum TerminalOutput: ACPMethod {
    public static let name = "terminal/output"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String
        public let terminalId: String

        public init(sessionId: String, terminalId: String) {
            self.sessionId = sessionId
            self.terminalId = terminalId
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public let output: String
        public let truncated: Bool
        public let exitStatus: TerminalExitStatus?

        public init(output: String, truncated: Bool, exitStatus: TerminalExitStatus? = nil) {
            self.output = output
            self.truncated = truncated
            self.exitStatus = exitStatus
        }
    }
}

/// `terminal/wait_for_exit` — agent asks the client to wait for a terminal to exit.
public enum WaitForTerminalExit: ACPMethod {
    public static let name = "terminal/wait_for_exit"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String
        public let terminalId: String

        public init(sessionId: String, terminalId: String) {
            self.sessionId = sessionId
            self.terminalId = terminalId
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public let exitCode: Int?
        public let signal: String?

        public init(exitCode: Int? = nil, signal: String? = nil) {
            self.exitCode = exitCode
            self.signal = signal
        }
    }
}

/// `terminal/kill` — agent asks the client to kill a terminal.
public enum KillTerminal: ACPMethod {
    public static let name = "terminal/kill"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String
        public let terminalId: String

        public init(sessionId: String, terminalId: String) {
            self.sessionId = sessionId
            self.terminalId = terminalId
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public init() {}
    }
}

/// `terminal/release` — agent asks the client to release a terminal.
public enum ReleaseTerminal: ACPMethod {
    public static let name = "terminal/release"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String
        public let terminalId: String

        public init(sessionId: String, terminalId: String) {
            self.sessionId = sessionId
            self.terminalId = terminalId
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public init() {}
    }
}

// MARK: - Exit Plan Mode (Agent → Client)

/// `exitPlanMode.request` — agent asks the client to exit plan mode.
public enum ExitPlanMode: ACPMethod {
    public static let name = "exitPlanMode.request"

    public struct Parameters: Codable, Hashable, Sendable {
        public let summary: String
        public let actions: [PlanAction]?
        public let recommendedAction: String?

        public init(summary: String, actions: [PlanAction]? = nil, recommendedAction: String? = nil) {
            self.summary = summary
            self.actions = actions
            self.recommendedAction = recommendedAction
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public let selectedAction: String
        public let feedback: String?

        public init(selectedAction: String, feedback: String? = nil) {
            self.selectedAction = selectedAction
            self.feedback = feedback
        }
    }
}

/// A single action the user can take when exiting plan mode.
public struct PlanAction: Codable, Hashable, Sendable, Identifiable {
    public var id: String { actionId }
    public let actionId: String
    public let label: String?
    public let description: String?

    public init(actionId: String, label: String? = nil, description: String? = nil) {
        self.actionId = actionId
        self.label = label
        self.description = description
    }
}

// MARK: - Terminal Exit Status

public struct TerminalExitStatus: Codable, Hashable, Sendable {
    public let exitCode: Int?
    public let signal: String?

    public init(exitCode: Int? = nil, signal: String? = nil) {
        self.exitCode = exitCode
        self.signal = signal
    }
}
