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
    public let version: String

    public init(name: String, version: String) {
        self.name = name
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
    public let version: String?
}

public struct AgentCapabilities: Codable, Hashable, Sendable {
    public let prompt: PromptCapabilities?
    public let loadSession: Bool?
    public let listSession: Bool?
    public let deleteSession: Bool?
    public let _meta: Value?

    enum CodingKeys: String, CodingKey {
        case prompt, loadSession, listSession, deleteSession, _meta
    }
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

        public init(sessionId: String, cwd: String? = nil) {
            self.sessionId = sessionId
            self.cwd = cwd
        }
    }

    public struct Result: Codable, Hashable, Sendable {
        public let sessionId: String
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
        public let mode: String

        public init(sessionId: String, mode: String) {
            self.sessionId = sessionId
            self.mode = mode
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
        public init() {}
    }
}

// MARK: - Session/List (RFD)

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
}

// MARK: - Session/Delete (RFD)

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

// MARK: - Supporting Types

public struct MCPServerConfig: Codable, Hashable, Sendable {
    public let name: String?
    public let uri: String?
    public let env: [EnvVariable]?

    public init(name: String? = nil, uri: String? = nil, env: [EnvVariable]? = nil) {
        self.name = name
        self.uri = uri
        self.env = env
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

public struct ModelsInfo: Codable, Hashable, Sendable {
    public let availableModels: [ModelInfo]?
    public let currentModelId: String?
}

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
